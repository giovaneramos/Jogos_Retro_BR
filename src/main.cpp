#include <cstdio>
#include <string>
#include <vector>

#if defined(__has_include)
  #if __has_include(<SDL2/SDL.h>)
    #include <SDL2/SDL.h>
  #else
    #include <SDL.h>
  #endif
#else
  #include <SDL.h>
#endif

#include "font8x8.hpp"

// Dimensões padrão da saída de vídeo do PS4 e PS5
constexpr int SCREEN_WIDTH  = 1920;
constexpr int SCREEN_HEIGHT = 1080;

// Paleta de temas para teste interativo
struct Theme {
    SDL_Color bg;
    SDL_Color card_bg;
    SDL_Color card_border;
    SDL_Color primary_text;
    SDL_Color accent_text;
};

const std::vector<Theme> THEMES = {
    // 0: Deep Playstation Blue (Padrão)
    {{10, 15, 30, 255},  {20, 32, 60, 255},  {0, 150, 255, 255}, {255, 255, 255, 255}, {0, 230, 255, 255}},
    // 1: Retro Cyberpunk Neon
    {{15, 10, 25, 255},  {35, 18, 55, 255},  {255, 0, 128, 255}, {255, 255, 255, 255}, {0, 255, 200, 255}},
    // 2: Classic Terminal Green
    {{5, 15, 5, 255},    {12, 35, 12, 255},  {40, 200, 40, 255}, {220, 255, 220, 255}, {80, 255, 80, 255}}
};

// Renderizador de texto bitmap 8x8 independente de fontes externas
void render_text(SDL_Renderer* renderer, const std::string& text, int start_x, int start_y, int scale, SDL_Color color) {
    SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);

    int cur_x = start_x;
    int cur_y = start_y;

    for (unsigned char c : text) {
        if (c == '\n') {
            cur_x = start_x;
            cur_y += 10 * scale;
            continue;
        }

        if (c > 127) c = '?';

        const uint8_t* glyph = font8x8_basic[c];
        for (int row = 0; row < 8; ++row) {
            uint8_t row_bits = glyph[row];
            for (int col = 0; col < 8; ++col) {
                if ((row_bits >> col) & 1) {
                    SDL_Rect pixel_rect = {
                        cur_x + (col * scale),
                        cur_y + (row * scale),
                        scale,
                        scale
                    };
                    SDL_RenderFillRect(renderer, &pixel_rect);
                }
            }
        }
        cur_x += (8 * scale) + (1 * scale);
    }
}

// Desenha um retângulo preenchido com borda
void render_card(SDL_Renderer* renderer, int x, int y, int w, int h, SDL_Color bg, SDL_Color border, int border_width = 3) {
    // Fundo
    SDL_SetRenderDrawColor(renderer, bg.r, bg.g, bg.b, bg.a);
    SDL_Rect rect = {x, y, w, h};
    SDL_RenderFillRect(renderer, &rect);

    // Borda
    SDL_SetRenderDrawColor(renderer, border.r, border.g, border.b, border.a);
    for (int i = 0; i < border_width; ++i) {
        SDL_Rect b = {x - i, y - i, w + (i * 2), h + (i * 2)};
        SDL_RenderDrawRect(renderer, &b);
    }
}

int main(int argc, char* argv[]) {
    (void)argc;
    (void)argv;

    printf("[RetroPlayer] Inicializando subsistemas SDL2...\n");

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER) != 0) {
        fprintf(stderr, "[ERRO] Falha ao inicializar SDL2: %s\n", SDL_GetError());
        return 1;
    }

    // Inicialização do controle DualShock 4 / DualSense
    SDL_GameController* controller = nullptr;
    std::string controller_name = "Nenhum controle detectado";
    for (int i = 0; i < SDL_NumJoysticks(); ++i) {
        if (SDL_IsGameController(i)) {
            controller = SDL_GameControllerOpen(i);
            if (controller) {
                const char* name = SDL_GameControllerName(controller);
                controller_name = name ? name : "Controle DualShock / DualSense";
                printf("[RetroPlayer] Controle detectado: %s\n", controller_name.c_str());
                break;
            }
        }
    }

    // Criação da Janela 1080p
    SDL_Window* window = SDL_CreateWindow(
        "Retro Player - PoC",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        SDL_WINDOW_SHOWN
    );

    if (!window) {
        fprintf(stderr, "[ERRO] Falha ao criar janela SDL: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    // Criação do Renderer com VSync ativado (60 FPS travado)
    SDL_Renderer* renderer = SDL_CreateRenderer(
        window,
        -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
    );

    if (!renderer) {
        fprintf(stderr, "[ERRO] Falha ao criar renderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    bool running = true;
    size_t current_theme = 0;
    std::string last_input = "Aguardando primeiro comando do controle...";
    uint32_t frame_count = 0;

    printf("[RetroPlayer] Loop principal iniciado com sucesso!\n");

    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                running = false;
            }
            // Eventos do DualShock 4 / DualSense via GameController API
            else if (event.type == SDL_CONTROLLERBUTTONDOWN) {
                switch (event.cbutton.button) {
                    case SDL_CONTROLLER_BUTTON_A: // Botão Cruz (X)
                        last_input = "[X] CRUZ: Botao pressionado com sucesso!";
                        current_theme = (current_theme + 1) % THEMES.size();
                        break;
                    case SDL_CONTROLLER_BUTTON_B: // Botão Círculo (O)
                        last_input = "[O] CIRCULO: Botao pressionado com sucesso!";
                        current_theme = (current_theme + THEMES.size() - 1) % THEMES.size();
                        break;
                    case SDL_CONTROLLER_BUTTON_X: // Botão Quadrado
                        last_input = "[] QUADRADO: Botao pressionado!";
                        break;
                    case SDL_CONTROLLER_BUTTON_Y: // Botão Triângulo
                        last_input = "/\\ TRIANGULO: Botao pressionado!";
                        break;
                    case SDL_CONTROLLER_BUTTON_DPAD_UP:
                        last_input = "D-PAD: CIMA";
                        break;
                    case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
                        last_input = "D-PAD: BAIXO";
                        break;
                    case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
                        last_input = "D-PAD: ESQUERDA";
                        break;
                    case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
                        last_input = "D-PAD: DIREITA";
                        break;
                    case SDL_CONTROLLER_BUTTON_START: // Botão Options
                        last_input = "[OPTIONS] Encerrando aplicativo...";
                        running = false;
                        break;
                    default:
                        last_input = "Botao ID: " + std::to_string(event.cbutton.button);
                        break;
                }
            }
            // Suporte auxiliar para teclado de depuração (Escape para sair, Enter para mudar tema)
            else if (event.type == SDL_KEYDOWN) {
                if (event.key.keysym.sym == SDLK_ESCAPE) {
                    running = false;
                } else if (event.key.keysym.sym == SDLK_RETURN || event.key.keysym.sym == SDLK_SPACE) {
                    current_theme = (current_theme + 1) % THEMES.size();
                    last_input = "TECLADO: Tecla de acao pressionada!";
                }
            }
        }

        const Theme& th = THEMES[current_theme];

        // 1. Limpeza do fundo com a cor do tema atual
        SDL_SetRenderDrawColor(renderer, th.bg.r, th.bg.g, th.bg.b, th.bg.a);
        SDL_RenderClear(renderer);

        // 2. Barra Superior de Título (Header)
        render_card(renderer, 60, 40, SCREEN_WIDTH - 120, 80, th.card_bg, th.card_border, 2);
        render_text(renderer, "RETRO PLAYER :: PS4 / PS5 HOMEBREW PROOF-OF-CONCEPT", 90, 68, 3, th.accent_text);

        // 3. Card Central: Mensagem de Sucesso ("DEU CERTO!")
        render_card(renderer, 160, 180, SCREEN_WIDTH - 320, 420, th.card_bg, th.card_border, 4);

        // Mensagem de Status em destaque (Escala 4x)
        SDL_Color green_ok = {40, 240, 80, 255};
        render_text(renderer, "[ SUCCESS ] O APLICATIVO INICIALIZOU COM SUCESSO!", 220, 230, 4, green_ok);

        // Detalhes técnicos da inicialização
        render_text(renderer, "Hardware Target : PlayStation 4 / PlayStation 5 (Retrocompatibilidade)", 220, 310, 3, th.primary_text);
        render_text(renderer, "Video Pipeline  : SDL2 Hardware Accelerated @ 1080p (60 FPS)", 220, 350, 3, th.primary_text);
        render_text(renderer, "Controle Ativo  : " + controller_name, 220, 390, 3, th.accent_text);
        render_text(renderer, "Title ID        : RETR00001 (Versao 01.00)", 220, 430, 3, th.primary_text);

        // Indicador de batimento de loop (Heartbeat / Animação suave de frames)
        int pulse = (frame_count / 15) % 4;
        std::string dots(pulse, '.');
        render_text(renderer, "Status Loop     : Executando normalmente" + dots, 220, 480, 3, green_ok);

        // 4. Card de Teste Interativo de Controles
        render_card(renderer, 160, 640, SCREEN_WIDTH - 320, 230, th.card_bg, th.card_border, 2);
        render_text(renderer, "CONTROLES E ENTRADAS DISPONIVEIS:", 200, 670, 3, th.accent_text);
        render_text(renderer, "[ X ] ou [ O ]   -> Alternar paleta de cores (Verde, Azul, Cyberpunk)", 220, 720, 2, th.primary_text);
        render_text(renderer, "[ D-PAD ]        -> Testar navegacao direcional", 220, 755, 2, th.primary_text);
        render_text(renderer, "[ OPTIONS ]      -> Sair com seguranca do aplicativo", 220, 790, 2, th.primary_text);

        // Feedback em tempo real do último comando
        render_text(renderer, "Ultimo Input: " + last_input, 220, 830, 2, th.accent_text);

        // 5. Rodapé
        render_text(renderer, "OpenOrbis Toolchain Build | Pronto para integracao com Core Libretro & Leitura USB", 160, 940, 2, th.accent_text);

        // Apresenta o frame
        SDL_RenderPresent(renderer);
        frame_count++;
    }

    printf("[RetroPlayer] Encerrando recursos...\n");

    if (controller) {
        SDL_GameControllerClose(controller);
    }
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    printf("[RetroPlayer] Finalizado com sucesso.\n");
    return 0;
}

