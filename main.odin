package two_breakouts

import "core:os"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"


RENDER_WIDTH  :: 568
RENDER_HEIGHT :: 320

WINDOW_WIDTH :: RENDER_WIDTH*2
WINDOW_HEIGHT :: RENDER_HEIGHT*2


CL_ORANGE :: rl.Color { 227, 81, 0, 255 }
CL_BLUE   :: rl.Color { 65, 97, 251, 255 }

ANALOG_PRESS :: 0.5
ANALOG_RELEASE :: 0.4

PADDLE_SIZE :: 40
PADDLE_SIZE_LONG :: 56

Root_State :: enum {
    Title,
    Game,
}


Input :: struct {
    // Menu Input
    menu_move: int, // Up or down.
    menu_decide: bool, // X
    menu_cancel: bool, // Circle

    // Previous analog state.
    analog_down: bool, // Keep true if analog is above 0.4

    // Game Input
    move: int,  // Analog or dpad.
    open: bool, // Any face button is down.
}

Ball_Color :: enum {
    Blue,
    Orange,
}

Ball :: struct {
    color: Ball_Color,
    pos, vel: [2]f32,
}

Game_State :: enum {
    Level_Start,
    Playing,
    Gameover,
}

Game :: struct {
    frame_count: int,
    state: Game_State,
    paddle_pos: f32,
    paddle_anim: f32,
    paddle_length: int,

    balls: [dynamic]Ball,
}

poll_input :: proc(input: ^Input) {
    input^ = { analog_down = input.analog_down }

    // Gamepad inputs
    analog_raw: f32
    for g_id in 0..<8 {
        g_id := i32(g_id)
        if rl.IsGamepadAvailable(g_id) {
            // Record analog for menu movement
            a := rl.GetGamepadAxisMovement(g_id, .LEFT_Y)
            if abs(a) > abs(analog_raw) {
                analog_raw = a
            }

            // Menu movement
            if rl.IsGamepadButtonPressed(g_id, .LEFT_FACE_UP) {
                input.menu_move = -1
            }
            if rl.IsGamepadButtonPressed(g_id, .LEFT_FACE_DOWN) {
                input.menu_move = 1
            }

            // Menu actions
            if rl.IsGamepadButtonPressed(g_id, .RIGHT_FACE_DOWN) {
                input.menu_decide = true
            }
            if rl.IsGamepadButtonPressed(g_id, .RIGHT_FACE_RIGHT) {
                input.menu_cancel = true
            }

            // Move in gameplay
            m := rl.GetGamepadAxisMovement(g_id, .LEFT_X)
            if abs(m) > ANALOG_PRESS {
                input.move = m > 0.0 ? 1 : -1
            }

            if rl.IsGamepadButtonDown(g_id, .LEFT_FACE_LEFT) {
                input.move = -1
            }
            if rl.IsGamepadButtonDown(g_id, .LEFT_FACE_RIGHT) {
                input.move = 1
            }

            // Open in gameplay
            if rl.IsGamepadButtonDown(g_id, .RIGHT_FACE_RIGHT) {
                input.open = true
            }
            if rl.IsGamepadButtonDown(g_id, .RIGHT_FACE_LEFT) {
                input.open = true
            }
            if rl.IsGamepadButtonDown(g_id, .RIGHT_FACE_UP) {
                input.open = true
            }
            if rl.IsGamepadButtonDown(g_id, .RIGHT_FACE_DOWN) {
                input.open = true
            }
        }
    }

    if input.analog_down {
        // Test for release
        if abs(analog_raw) < ANALOG_RELEASE {
            input.analog_down = false
        }
    } else {
        // Test for press
        if abs(analog_raw) > ANALOG_PRESS {
            input.analog_down = true
            input.menu_move = analog_raw > 0.0 ? 1 : -1
        }
    }


    // Keyboard inputs
    KEY_SETS :: [3][4]rl.KeyboardKey {
        { .W, .A, .S, .D, },
        { .I, .J, .K, .L, },
        { .UP, .LEFT, .DOWN, .RIGHT, },
    }

    UP    :: 0
    LEFT  :: 1
    DOWN  :: 2
    RIGHT :: 3
    for key_set in KEY_SETS {
        // Menu movement
        if rl.IsKeyPressed(key_set[UP]) {
            input.menu_move = -1
        }
        if rl.IsKeyPressed(key_set[DOWN]) {
            input.menu_move = 1
        }

        // Move in gameplay
        if rl.IsKeyDown(key_set[LEFT]) {
            input.move = -1
        }
        if rl.IsKeyDown(key_set[RIGHT]) {
            input.move = 1
        }

        // Open in gameplay
        if rl.IsKeyDown(key_set[DOWN]) {
            input.open = true
        }
    }

    if rl.IsKeyPressed(.ENTER) {
        input.menu_decide = true
    }
    if rl.IsKeyPressed(.BACKSPACE) {
        input.menu_cancel = true
    }
}

game_init :: proc(game: ^Game) {
    game^ = {}
    game.state = .Level_Start
    game.paddle_pos = RENDER_WIDTH / 2 - 20
    game.paddle_anim = 0
    game.paddle_length = PADDLE_SIZE
}

draw_paddle :: proc(pos: [2]f32, frame, length: int, orange: bool) {
    pos := [2]f32 { math.floor(pos.x), math.floor(pos.y) }
    src_l := rl.Rectangle {
        f32(frame*40),
        0,
        20,
        16,
    }

    texture := sprites[.Paddle_Blue]
    if orange {
        texture = sprites[.Paddle_Orange]
        src_l.height = -src_l.height
    }

    dst_l := rl.Rectangle {
        pos.x - f32(length / 2),
        pos.y,
        20,
        16,
    }
    src_r := rl.Rectangle {
        src_l.x + 20,
        0,
        20,
        src_l.height,
    }
    dst_r := rl.Rectangle {
        dst_l.x + f32(length) - 20,
        dst_l.y,
        20,
        16,
    }


    // Draw left side and right side
    rl.DrawTexturePro(texture, src_l, dst_l, 0, 0, rl.WHITE)
    rl.DrawTexturePro(texture, src_r, dst_r, 0, 0, rl.WHITE)

    // Draw middle part when length is bigger than 40
    if length > PADDLE_SIZE && frame == 0 {
        src_m := rl.Rectangle {
            src_l.x + 16,
            0,
            8,
            src_l.height,
        }
        for i in 0..=(length - 40) / 8 {
            dst_m := rl.Rectangle {
                dst_l.x + f32(i*8) + 20,
                dst_l.y,
                8,
                16,
            }
            rl.DrawTexturePro(texture, src_m, dst_m, 0, 0, rl.WHITE)
        }
    }
}

game_update :: proc(game: ^Game, input: Input) {
    game.frame_count += 1

    move_speed := f32(1)
    if game.paddle_anim > 0.2 {
        move_speed = 0.25
    }
    game.paddle_pos += f32(input.move)*move_speed

    if input.open {
        game.paddle_anim += 0.05
    } else {
        game.paddle_anim -= 0.05
    }
    game.paddle_anim = clamp(game.paddle_anim, 0, 1)

    paddle_y := f32(RENDER_HEIGHT / 2) - 16
    draw_paddle({ game.paddle_pos, paddle_y      }, int(game.paddle_anim*3), game.paddle_length, false)
    draw_paddle({ game.paddle_pos, paddle_y + 16 }, int(game.paddle_anim*3), game.paddle_length, true)
}

sprites: [Sprite_Tag]rl.Texture

main :: proc() {
    rl.SetConfigFlags({ .WINDOW_RESIZABLE, .FULLSCREEN_MODE, .WINDOW_MAXIMIZED })
    rl.SetTargetFPS(60)

    rl.InitWindow(0, 0, "2 Breakouts! 🕹")
    windowed_width  := i32(WINDOW_WIDTH)
    windowed_height := i32(WINDOW_HEIGHT)

    render_texture := rl.LoadRenderTexture(RENDER_WIDTH, RENDER_HEIGHT)
    if !rl.IsRenderTextureValid(render_texture) {
        fmt.eprint("Render texture failed to initialize!!")
        os.exit(-1)
    }

    for tag in Sprite_Tag {
        image := rl.LoadImageFromMemory(".png", &sprites_load[tag][0], i32(len(sprites_load[tag])))
        sprites[tag] = rl.LoadTextureFromImage(image)
        rl.UnloadImage(image)
    }

    root_state := Root_State.Game

    input: Input
    game: Game

    game_init(&game)

    for !rl.WindowShouldClose() {
        if rl.IsKeyDown(.LEFT_ALT) && rl.IsKeyPressed(.ENTER) {
            if !rl.IsWindowFullscreen() {
                windowed_width = rl.GetScreenWidth()
                windowed_height = rl.GetScreenHeight()
                monitor := rl.GetCurrentMonitor()
                width := rl.GetMonitorWidth(monitor)
                height := rl.GetMonitorHeight(monitor)
                rl.SetWindowSize(width, height)
                rl.ToggleFullscreen()
            } else {
                rl.ToggleFullscreen()
                monitor := rl.GetCurrentMonitor()
                width := rl.GetMonitorWidth(monitor)
                height := rl.GetMonitorHeight(monitor)
                rl.SetWindowSize(windowed_width, windowed_height)
                rl.SetWindowPosition((width - windowed_width) / 2, (height - windowed_height) / 2)
            }
        }

        rl.BeginDrawing()

        // Render actual game to render texture.
        rl.BeginTextureMode(render_texture)
        rl.ClearBackground(rl.BLACK)
        
        {
            top_color := rl.ColorBrightness(CL_BLUE, -0.5)
            bot_color := rl.ColorBrightness(CL_ORANGE, -0.5)
            limit := int(RENDER_HEIGHT / 16)
            lh := limit / 2
            for i in 0..<limit {
                color: rl.Color
                if i < lh {
                    color = rl.ColorLerp(top_color, rl.BLACK, f32(i) / f32(lh))
                } else {
                    color = rl.ColorLerp(bot_color, rl.BLACK, 1.0 - (f32(i + 1 - lh) / f32(lh)))
                }
                y := i32(i*16)
                rl.DrawRectangle(0, y, RENDER_WIDTH, 16, color)
            }
        }


        poll_input(&input)

        switch root_state {
        case .Title:
        case .Game:
            game_update(&game, input)
        }

        rl.EndTextureMode()

        // Fit the game screen to any resolution.
        {
            src := rl.Rectangle {
                0,
                0,
                RENDER_WIDTH,
                -RENDER_HEIGHT,
            }

            res := [2]f32 { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
            scale := min(res.x / RENDER_WIDTH, res.y / RENDER_HEIGHT)
            dst_res := [2]f32 { RENDER_WIDTH, RENDER_HEIGHT } * scale
            dst_offset := (res - dst_res) / 2
            dst := rl.Rectangle {
                dst_offset.x,
                dst_offset.y,
                dst_res.x,
                dst_res.y,
            }
            rl.DrawTexturePro(render_texture.texture, src, dst, 0, 0, rl.WHITE)
        }

        rl.EndDrawing()
    }
}
