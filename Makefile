# ==============================================================================
# OpenOrbis PS4/PS5 Toolchain Makefile - Retro Player Homebrew
# Title ID: RETR00001 | App: Retro Player
# ==============================================================================

# 1. Verificação da Toolchain OpenOrbis
ifndef OO_PS4_TOOLCHAIN
    $(error [ERRO] A variável de ambiente OO_PS4_TOOLCHAIN não está definida. Defina com: export OO_PS4_TOOLCHAIN=/caminho/para/OpenOrbis/PS4-Toolchain)
endif

# 2. Configurações da Aplicação
APP_NAME    := RetroPlayer
TITLE_ID    := RETR00001
CONTENT_ID  := IV0000-$(TITLE_ID)_00-0000000000000000
VERSION     := 01.00

# 3. Resolução de Sistema Operacional e Binários da Toolchain
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    HOST_OS := macosx
else ifeq ($(UNAME_S),Linux)
    HOST_OS := linux
else
    HOST_OS := windows
endif

# Detecta se os binários estão em bin/<os> ou diretamente em bin/
ifneq ($(wildcard $(OO_PS4_TOOLCHAIN)/bin/$(HOST_OS)/clang*),)
    TOOL_DIR := $(OO_PS4_TOOLCHAIN)/bin/$(HOST_OS)
else
    TOOL_DIR := $(OO_PS4_TOOLCHAIN)/bin
endif

# Detecção de compiladores (prioriza toolchain, fallback para clang do sistema)
ifneq ($(wildcard $(TOOL_DIR)/clang++),)
    CXX := $(TOOL_DIR)/clang++
    CC  := $(TOOL_DIR)/clang
else
    CXX := clang++
    CC  := clang
endif

# Detecção do conversor de eboot (create-eboot ou create-fself)
ifneq ($(wildcard $(TOOL_DIR)/create-eboot*),)
    CREATE_EBOOT := $(TOOL_DIR)/create-eboot
else ifneq ($(wildcard $(TOOL_DIR)/create-fself*),)
    CREATE_EBOOT := $(TOOL_DIR)/create-fself
else
    CREATE_EBOOT := create-eboot
endif

PKG_TOOL     := $(TOOL_DIR)/PkgTool.Core
CREATE_PKG   := $(TOOL_DIR)/create-pkg
ORBIS_PUB    := $(TOOL_DIR)/orbis-pub-cmd
SYSROOT      := $(OO_PS4_TOOLCHAIN)/target

# 4. Diretórios do Projeto
SRC_DIR     := src
INC_DIR     := include
ASSETS_DIR  := assets
SCE_SYS_DIR := sce_sys
BUILD_DIR   := build
DIST_DIR    := dist
STAGE_DIR   := $(BUILD_DIR)/stage

# 5. Fontes e Objetos
SRCS_CPP := $(wildcard $(SRC_DIR)/*.cpp)
SRCS_C   := $(wildcard $(SRC_DIR)/*.c)
OBJS     := $(patsubst $(SRC_DIR)/%.cpp, $(BUILD_DIR)/%.o, $(SRCS_CPP)) \
            $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(SRCS_C))

# 6. Flags de Compilação e Linkagem
# OpenOrbis utiliza arquitetura x86_64-scei-ps4-elf (FreeBSD-like)
COMMON_FLAGS := --target=x86_64-scei-ps4-elf \
                -isysroot $(SYSROOT) \
                -isystem $(SYSROOT)/include \
                -I$(INC_DIR) \
                -I$(SYSROOT)/include/SDL2 \
                -O2 -Wall -Wextra -fPIC \
                -D__ORBIS__ -D__PS4__

CFLAGS   := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS) -std=c++17

# Bibliotecas: Kernel, C/C++, Video, Controle (Pad), Módulos do Sistema e SDL2
LDFLAGS  := --target=x86_64-scei-ps4-elf \
            -isysroot $(SYSROOT) \
            -L$(SYSROOT)/lib \
            -fuse-ld=lld \
            -pie \
            -lkernel -lc -lc++ \
            -lSceVideoOut -lScePad -lSceSysmodule \
            -lSDL2 -lSDL2_ttf -lSDL2_image

# 7. Regras Principais
.PHONY: all clean stage pkg sfo

all: $(STAGE_DIR)/eboot.bin

# Compilação C++
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(BUILD_DIR)
	@echo " [CXX] $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Compilação C
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	@echo " [CC]  $<"
	@$(CC) $(CFLAGS) -c $< -o $@

# Linkagem do ELF intermediário
$(BUILD_DIR)/$(APP_NAME).elf: $(OBJS)
	@echo " [LD]  $@"
	@$(CXX) $(OBJS) $(LDFLAGS) -o $@

# Criação do eboot.bin assinado (Fake Signed / FSELF)
$(STAGE_DIR)/eboot.bin: $(BUILD_DIR)/$(APP_NAME).elf
	@mkdir -p $(STAGE_DIR)
	@echo " [EBOOT] Gerando $(STAGE_DIR)/eboot.bin com Fake PAID..."
	@$(CREATE_EBOOT) --in=$< --out=$@ --paid=0x3800000000000011

# Montagem da pasta de Staging para o PKG
stage: all sfo
	@echo " [STAGE] Preparando estrutura para empacotamento..."
	@mkdir -p $(STAGE_DIR)/sce_sys
	@if [ -d "$(SCE_SYS_DIR)" ]; then cp -rf $(SCE_SYS_DIR)/* $(STAGE_DIR)/sce_sys/ 2>/dev/null || true; fi
	@if [ -d "$(ASSETS_DIR)" ]; then cp -rf $(ASSETS_DIR) $(STAGE_DIR)/ 2>/dev/null || true; fi
	@echo " [STAGE] Estrutura montada em $(STAGE_DIR)."

# Geração do arquivo param.sfo via script auxiliar
sfo:
	@if [ -f "scripts/generate_sfo.sh" ]; then \
		echo " [SFO] Executando scripts/generate_sfo.sh..."; \
		bash scripts/generate_sfo.sh; \
	else \
		echo " [SFO] Script scripts/generate_sfo.sh ainda não criado."; \
	fi

# Criação do arquivo .pkg final
pkg: stage sfo
	@mkdir -p $(DIST_DIR)
	@echo " [PKG] Construindo pacote no diretório $(DIST_DIR)..."
	@if [ -x "$(PKG_TOOL)" ] && [ -f "scripts/package.gp4" ]; then \
		echo " [PKG] Empacotando com PkgTool.Core..."; \
		$(PKG_TOOL) pkg_build scripts/package.gp4 $(DIST_DIR); \
	elif command -v $(ORBIS_PUB) >/dev/null 2>&1 && [ -f "scripts/package.gp4" ]; then \
		echo " [PKG] Empacotando com orbis-pub-cmd..."; \
		$(ORBIS_PUB) img_create scripts/package.gp4 $(DIST_DIR)/$(APP_NAME)_$(TITLE_ID).pkg; \
	elif [ -x "$(CREATE_PKG)" ]; then \
		echo " [PKG] Empacotando com create-pkg..."; \
		$(CREATE_PKG) --input=$(STAGE_DIR) --output=$(DIST_DIR)/$(APP_NAME)_$(TITLE_ID).pkg --content_id=$(CONTENT_ID); \
	elif command -v create-pkg >/dev/null 2>&1; then \
		echo " [PKG] Empacotando com create-pkg (PATH)..."; \
		create-pkg --input=$(STAGE_DIR) --output=$(DIST_DIR)/$(APP_NAME)_$(TITLE_ID).pkg --content_id=$(CONTENT_ID); \
	else \
		echo " [AVISO] Nenhum empacotador automatizado (PkgTool.Core, create-pkg, orbis-pub-cmd) encontrado."; \
		echo "         A pasta de staging '$(STAGE_DIR)' está pronta para empacotamento manual via orbis-pub-cmd-gui ou PS4-Fake-PKG-Tools."; \
	fi
	@echo " [SUCESSO] Processo de build concluído!"

clean:
	@echo " [CLEAN] Limpando diretórios de build e distribuição..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
	@echo " [CLEAN] Pronto."

