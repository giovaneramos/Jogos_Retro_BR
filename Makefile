# ==============================================================================
# OpenOrbis PS4/PS5 Toolchain Makefile - Retro Player Homebrew
# Title ID: RETR00001 | App: Retro Player
# ==============================================================================

# 1. Metadados do Pacote
APP_NAME    := RetroPlayer
TITLE       := Retro Player
VERSION     := 01.00
TITLE_ID    := RETR00001
CONTENT_ID  := IV0000-$(TITLE_ID)_00-0000000000000000

# 2. Resolução da Toolchain
ifndef OO_PS4_TOOLCHAIN
    $(error [ERRO] A variável OO_PS4_TOOLCHAIN não está definida.)
endif
TOOLCHAIN := $(OO_PS4_TOOLCHAIN)

# 3. Resolução de Sistema Operacional e Ferramentas
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    CDIR := macos
else ifeq ($(UNAME_S),Linux)
    CDIR := linux
else
    CDIR := windows
endif

CC   := clang
CXX  := clang++
LD   := $(shell command -v ld.lld 2>/dev/null || command -v lld 2>/dev/null || echo "ld.lld")

CREATE_FSELF := $(firstword $(wildcard $(TOOLCHAIN)/bin/$(CDIR)/create-fself $(TOOLCHAIN)/bin/create-fself create-fself))
PKG_TOOL     := $(firstword $(wildcard $(TOOLCHAIN)/bin/$(CDIR)/PkgTool.Core $(TOOLCHAIN)/bin/PkgTool.Core PkgTool.Core))

# 4. Diretórios
SRC_DIR     := src
INC_DIR     := include
SCE_SYS_DIR := sce_sys
ASSETS_DIR  := assets
BUILD_DIR   := build
DIST_DIR    := dist
STAGE_DIR   := $(BUILD_DIR)/stage

# 5. Fontes e Objetos
SRCS_CPP := $(wildcard $(SRC_DIR)/*.cpp)
SRCS_C   := $(wildcard $(SRC_DIR)/*.c)
OBJS     := $(patsubst $(SRC_DIR)/%.cpp, $(BUILD_DIR)/%.o, $(SRCS_CPP)) \
            $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(SRCS_C))

# 6. Flags do Compilador e Linker (Padrão Oficial OpenOrbis)
COMMON_FLAGS := --target=x86_64-pc-freebsd12-elf \
                -fPIC -funwind-tables -O2 \
                -isysroot $(TOOLCHAIN) \
                -isystem $(TOOLCHAIN)/include \
                -isystem $(TOOLCHAIN)/include/SDL2 \
                -I$(INC_DIR) \
                -D__ORBIS__ -D__PS4__ -DPS4=1

CFLAGS   := $(COMMON_FLAGS) -c
CXXFLAGS := $(COMMON_FLAGS) -c -std=c++17 -isystem $(TOOLCHAIN)/include/c++/v1

LIBS := -lc -lkernel -lc++ -lSceUserService -lSceVideoOut -lSceAudioOut -lScePad -lSceSysmodule -lSDL2

LDFLAGS := -m elf_x86_64 -pie --script $(TOOLCHAIN)/link.x --eh-frame-hdr -L$(TOOLCHAIN)/lib $(LIBS) $(TOOLCHAIN)/lib/crt1.o

# 7. Regras Principais
.PHONY: all clean stage pkg sfo

all: $(STAGE_DIR)/eboot.bin

# Compilação C++
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(BUILD_DIR)
	@echo " [CXX] $<"
	$(CXX) $(CXXFLAGS) -o $@ $<

# Compilação C
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	@echo " [CC]  $<"
	$(CC) $(CFLAGS) -o $@ $<

# Linkagem direta com ld.lld usando linker script OpenOrbis
$(BUILD_DIR)/$(APP_NAME).elf: $(OBJS)
	@mkdir -p $(BUILD_DIR)
	@echo " [LD]  $@"
	$(LD) $(OBJS) -o $@ $(LDFLAGS)

# Conversão para eboot.bin com Fake PAID
$(STAGE_DIR)/eboot.bin: $(BUILD_DIR)/$(APP_NAME).elf
	@mkdir -p $(STAGE_DIR)
	@if [ -z "$(CREATE_FSELF)" ]; then \
		echo " [ERRO] create-fself não foi localizado em $(TOOLCHAIN)/bin/$(CDIR)/"; \
		exit 1; \
	fi
	@echo " [EBOOT] Gerando $(STAGE_DIR)/eboot.bin com $(CREATE_FSELF)..."
	$(CREATE_FSELF) -in=$< -out=$(BUILD_DIR)/$(APP_NAME).oelf --eboot="$@" --paid 0x3800000000000011

# Montagem de Staging
stage: all sfo
	@mkdir -p $(STAGE_DIR)/sce_sys
	@if [ -d "$(SCE_SYS_DIR)" ]; then cp -rf $(SCE_SYS_DIR)/* $(STAGE_DIR)/sce_sys/ 2>/dev/null || true; fi
	@if [ -d "$(ASSETS_DIR)" ]; then cp -rf $(ASSETS_DIR) $(STAGE_DIR)/ 2>/dev/null || true; fi
	@echo " [STAGE] Estrutura montada em $(STAGE_DIR)."

# Geração de param.sfo se necessário
sfo:
	@if [ ! -f "$(SCE_SYS_DIR)/param.sfo" ] && [ -n "$(PKG_TOOL)" ]; then \
		echo " [SFO] Gerando param.sfo com PkgTool.Core..."; \
		mkdir -p $(SCE_SYS_DIR); \
		$(PKG_TOOL) sfo_new $(SCE_SYS_DIR)/param.sfo; \
		$(PKG_TOOL) sfo_setentry $(SCE_SYS_DIR)/param.sfo APP_TYPE --type Integer --maxsize 4 --value 1; \
		$(PKG_TOOL) sfo_setentry $(SCE_SYS_DIR)/param.sfo APP_VER --type Utf8 --maxsize 8 --value '$(VERSION)'; \
		$(PKG_TOOL) sfo_setentry $(SCE_SYS_DIR)/param.sfo CATEGORY --type Utf8 --maxsize 4 --value 'gd'; \
		$(PKG_TOOL) sfo_setentry $(SCE_SYS_DIR)/param.sfo CONTENT_ID --type Utf8 --maxsize 48 --value '$(CONTENT_ID)'; \
		$(PKG_TOOL) sfo_setentry $(SCE_SYS_DIR)/param.sfo TITLE --type Utf8 --maxsize 128 --value '$(TITLE)'; \
		$(PKG_TOOL) sfo_setentry $(SCE_SYS_DIR)/param.sfo TITLE_ID --type Utf8 --maxsize 12 --value '$(TITLE_ID)'; \
		$(PKG_TOOL) sfo_setentry $(SCE_SYS_DIR)/param.sfo VERSION --type Utf8 --maxsize 8 --value '$(VERSION)'; \
	fi

# Construção do pacote .pkg
pkg: stage
	@mkdir -p $(DIST_DIR)
	@if [ -z "$(PKG_TOOL)" ]; then \
		echo " [ERRO] PkgTool.Core não foi localizado em $(TOOLCHAIN)/bin/$(CDIR)/"; \
		exit 1; \
	fi
	@echo " [PKG] Construindo pacote no diretório $(DIST_DIR) usando $(PKG_TOOL)..."
	$(PKG_TOOL) pkg_build package.gp4 $(DIST_DIR)
	@echo " [SUCESSO] Pacote .pkg gerado com sucesso!"

clean:
	@echo " [CLEAN] Limpando diretórios..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
