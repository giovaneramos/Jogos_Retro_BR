# ==============================================================================
# OpenOrbis PS4/PS5 Toolchain Makefile - Retro Player Homebrew
# Title ID: RETR00001 | App: Retro Player
# ==============================================================================

# 1. Verificação da Toolchain OpenOrbis
ifndef OO_PS4_TOOLCHAIN
    $(error [ERRO] A variável de ambiente OO_PS4_TOOLCHAIN não está definida. Defina com: export OO_PS4_TOOLCHAIN=/caminho/para/OpenOrbis/PS4-Toolchain)
endif

TOOLCHAIN := $(OO_PS4_TOOLCHAIN)

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

# Diretório de binários da Toolchain
ifneq ($(wildcard $(TOOLCHAIN)/bin/$(HOST_OS)),)
    TOOL_DIR := $(TOOLCHAIN)/bin/$(HOST_OS)
else
    TOOL_DIR := $(TOOLCHAIN)/bin
endif

# Compiladores: prioriza binários da toolchain, fallback para clang do sistema
ifneq ($(wildcard $(TOOL_DIR)/clang++),)
    CXX := $(TOOL_DIR)/clang++
    CC  := $(TOOL_DIR)/clang
else
    CXX := clang++
    CC  := clang
endif

# Ferramentas OpenOrbis
CREATE_EBOOT := $(shell command -v create-eboot 2>/dev/null || command -v create-fself 2>/dev/null || firstword $(wildcard $(TOOL_DIR)/create-eboot $(TOOL_DIR)/create-fself $(TOOLCHAIN)/bin/create-eboot $(TOOLCHAIN)/bin/create-fself create-eboot create-fself))
PKG_TOOL     := $(shell command -v PkgTool.Core 2>/dev/null || firstword $(wildcard $(TOOL_DIR)/PkgTool.Core $(TOOLCHAIN)/bin/PkgTool.Core /usr/local/bin/PkgTool.Core PkgTool.Core))
CREATE_PKG   := $(shell command -v create-pkg 2>/dev/null || firstword $(wildcard $(TOOL_DIR)/create-pkg $(TOOLCHAIN)/bin/create-pkg create-pkg))
ORBIS_PUB    := $(shell command -v orbis-pub-cmd 2>/dev/null || firstword $(wildcard $(TOOL_DIR)/orbis-pub-cmd $(TOOLCHAIN)/bin/orbis-pub-cmd orbis-pub-cmd))

# Diretórios de Headers e Bibliotecas
ifneq ($(wildcard $(TOOLCHAIN)/target/include),)
    INC_SYS := $(TOOLCHAIN)/target/include
    LIB_SYS := $(TOOLCHAIN)/target/lib
else
    INC_SYS := $(TOOLCHAIN)/include
    LIB_SYS := $(TOOLCHAIN)/lib
endif

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
# Alvo FreeBSD/Orbis ELF suportado nativamente pelo Clang
COMMON_FLAGS := --target=x86_64-pc-freebsd12-elf \
                -fPIC -funwind-tables -O2 -Wall -Wextra \
                -isysroot $(TOOLCHAIN) \
                -isystem $(INC_SYS) \
                -I$(INC_DIR) \
                -I$(INC_SYS)/SDL2 \
                -D__ORBIS__ -D__PS4__ -DPS4=1

CFLAGS   := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS) -std=c++17 -isystem $(INC_SYS)/c++/v1

# Script do linker e startup object (se existirem na toolchain)
ifneq ($(wildcard $(TOOLCHAIN)/link.x),)
    LDSCRIPT_FLAG := -Wl,--script=$(TOOLCHAIN)/link.x
endif
CRT1_OBJ := $(wildcard $(LIB_SYS)/crt1.o)

# Bibliotecas nativas essenciais + SDL2
LIBS := -lc -lkernel -lc++ -lSceVideoOut -lScePad -lSceSysmodule -lSDL2

LDFLAGS := --target=x86_64-pc-freebsd12-elf \
           -fuse-ld=lld \
           -pie \
           -L$(LIB_SYS) \
           $(LDSCRIPT_FLAG) \
           -Wl,--eh-frame-hdr \
           $(CRT1_OBJ) \
           $(LIBS)

# 7. Regras Principais
.PHONY: all clean stage pkg sfo

all: $(STAGE_DIR)/eboot.bin

# Compilação C++
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(BUILD_DIR)
	@echo " [CXX] $<"
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compilação C
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	@echo " [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Linkagem do binário ELF intermediário
$(BUILD_DIR)/$(APP_NAME).elf: $(OBJS)
	@echo " [LD]  $@"
	$(CXX) $(OBJS) $(LDFLAGS) -o $@

# Conversão para eboot.bin com Fake Program Authentication ID (PAID 0x3800000000000011)
$(STAGE_DIR)/eboot.bin: $(BUILD_DIR)/$(APP_NAME).elf
	@mkdir -p $(STAGE_DIR)
	@echo " [EBOOT] Gerando $(STAGE_DIR)/eboot.bin com Fake PAID..."
	@if command -v create-fself >/dev/null 2>&1; then \
		create-fself -in $< --eboot $@ --paid 0x3800000000000011 || \
		create-fself -in=$< --out=$@ --paid=0x3800000000000011 || \
		create-fself --in=$< --out=$@ --paid=0x3800000000000011; \
	elif [ -n "$(CREATE_EBOOT)" ]; then \
		$(CREATE_EBOOT) -in $< --eboot $@ --paid 0x3800000000000011 || \
		$(CREATE_EBOOT) -in=$< --out=$@ --paid=0x3800000000000011 || \
		$(CREATE_EBOOT) --in=$< --out=$@ --paid=0x3800000000000011; \
	else \
		echo " [ERRO] create-fself ou create-eboot não encontrado."; exit 1; \
	fi

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
	@if command -v PkgTool.Core >/dev/null 2>&1 && [ -f "scripts/package.gp4" ]; then \
		echo " [PKG] Empacotando com PkgTool.Core..."; \
		PkgTool.Core pkg_build scripts/package.gp4 $(DIST_DIR); \
	elif [ -n "$(PKG_TOOL)" ] && [ -x "$(PKG_TOOL)" ] && [ -f "scripts/package.gp4" ]; then \
		echo " [PKG] Empacotando com $(PKG_TOOL)..."; \
		$(PKG_TOOL) pkg_build scripts/package.gp4 $(DIST_DIR); \
	elif command -v create-pkg >/dev/null 2>&1; then \
		echo " [PKG] Empacotando com create-pkg..."; \
		create-pkg --input=$(STAGE_DIR) --output=$(DIST_DIR)/$(APP_NAME)_$(TITLE_ID).pkg --content_id=$(CONTENT_ID); \
	elif command -v $(ORBIS_PUB) >/dev/null 2>&1 && [ -f "scripts/package.gp4" ]; then \
		echo " [PKG] Empacotando com orbis-pub-cmd..."; \
		$(ORBIS_PUB) img_create scripts/package.gp4 $(DIST_DIR)/$(APP_NAME)_$(TITLE_ID).pkg; \
	else \
		echo " [AVISO] Nenhum empacotador CLI automatizado encontrado. Arquivos de staging prontos em $(STAGE_DIR)."; \
	fi
	@echo " [SUCESSO] Processo de build concluído!"

clean:
	@echo " [CLEAN] Limpando diretórios de build e distribuição..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
	@echo " [CLEAN] Pronto."
