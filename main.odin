package two_breakouts

import "core:os"
import "core:fmt"
import "core:math"
import "core:math/linalg"
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

TILE_SIZE :: 8
BOARD_WIDTH :: 20
BOARD_HEIGHT :: 20

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
    held: bool,
    held_timer: int,

    dead: bool,
    dead_timer: int,
}

Game_State :: enum {
    Level_Start,
    Playing,
    Gameover,
}

Game :: struct {
    frame_count: int,
    state: Game_State,
    state_timer: int,

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
    game.paddle_pos = RENDER_WIDTH / 2
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

paddle_get_y :: proc(orange: bool) -> f32 {
    paddle_y := f32(RENDER_HEIGHT / 2) - 16
    if orange {
        paddle_y += 16
    }
    return paddle_y
}

ball_spawn :: proc(balls: ^[dynamic]Ball, orange: bool) {
    ball := Ball {
        color = orange ? .Orange : .Blue,
        pos = orange ? paddle_get_y(orange) + 16 : paddle_get_y(orange) - 8,
        vel = orange ? { 1, 1 } : { -1, -1 },

        held = true,
        held_timer = 180,
    }
    append(balls, ball)
}

bounce_rect :: proc(pos, vel: ^[2]f32, rect: rl.Rectangle) -> bool {
    brec := rl.Rectangle {
        pos.x,
        pos.y,
        8,
        8,
    }
    if rl.CheckCollisionRecs(brec, rect) {
        c := pos^ + { 4, 4 }
        if c.x >= rect.x && c.x <= rect.x + rect.width {
            vel.y = -vel.y
        } else if c.y >= rect.y && c.y <= rect.y + rect.height {
            vel.x = -vel.x
        } else {
        }
        return true
    }
    return false
}

game_update :: proc(game: ^Game, input: Input) {
    game.frame_count += 1

    move_speed := f32(1)
    if game.paddle_anim > 0.2 {
        move_speed = 0.25
    }
    game.paddle_pos += f32(input.move)*move_speed

    board_l := f32((RENDER_WIDTH - BOARD_WIDTH*TILE_SIZE) / 2)
    board_r := f32(board_l + BOARD_WIDTH*TILE_SIZE)
    game.paddle_pos = clamp(game.paddle_pos, board_l + f32(game.paddle_length / 2), board_r - f32(game.paddle_length / 2))

    if input.open {
        game.paddle_anim += 0.05
    } else {
        game.paddle_anim -= 0.05
    }
    game.paddle_anim = clamp(game.paddle_anim, 0, 1)

    death_zones: [2]rl.Rectangle
    if game.paddle_anim < 0.5 {
        death_zones[0] = rl.Rectangle {
            board_l,
            RENDER_HEIGHT / 2 - 8,
            game.paddle_pos - board_l,
            16,
        }
        death_zones[1] = rl.Rectangle {
            game.paddle_pos,
            RENDER_HEIGHT / 2 - 8,
            board_r - game.paddle_pos,
            16,
        }
    } else {
        death_zones[0] = rl.Rectangle {
            board_l,
            RENDER_HEIGHT / 2 - 8,
            game.paddle_pos - f32(game.paddle_length / 2) - board_l,
            16,
        }
        x := game.paddle_pos + f32(game.paddle_length / 2)
        death_zones[1] = rl.Rectangle {
            x,
            RENDER_HEIGHT / 2 - 8,
            board_r - x,
            16,
        }
    }

    if rl.IsKeyPressed(.ENTER) {
        ball_spawn(&game.balls, false)
    }
    if rl.IsKeyPressed(.BACKSPACE) {
        ball_spawn(&game.balls, true)
    }

    #reverse for &ball, i in game.balls {
        if ball.held {
            ball.pos.x = game.paddle_pos - 4
            ball.held_timer -= 1
            if ball.held_timer <= 0 {
                ball.held = false
            }
            continue
        }

        if ball.dead {
            ball.dead_timer -= 1
            if ball.dead_timer <= 0 {
                unordered_remove(&game.balls, i)
            }
            continue
        }

        if ball.vel.x < 0 {
            if ball.pos.x < board_l {
                ball.vel.x = -ball.vel.x
                // SOUND
            }
        } else {
            if ball.pos.x > board_r - 8 {
                ball.vel.x = -ball.vel.x
                // SOUND
            }
        }
        if ball.vel.y < 0 {
            if ball.pos.y < 8 {
                ball.vel.y = -ball.vel.y
                // SOUND
            }
        } else {
            if ball.pos.y > RENDER_HEIGHT - 16 {
                ball.vel.y = -ball.vel.y
                // SOUND
            }
        }

        rect_ball := rl.Rectangle {
            ball.pos.x,
            ball.pos.y,
            8,
            8,
        }
        if game.paddle_anim < 0.5 {
            if ball.vel.y > 0 {
                rect_bl := rl.Rectangle {
                    game.paddle_pos - f32(game.paddle_length / 2),
                    paddle_get_y(false),
                    f32(game.paddle_length),
                    8,
                }
                if rl.CheckCollisionRecs(rect_bl, rect_ball) {
                    a := linalg.atan2(ball.vel.y, ball.vel.x)
                    s := linalg.length(ball.vel)
                    min_a := a - 1.0
                    max_a := a + 1.0
                    t := 1.0 - math.saturate((ball.pos.x + 4 - rect_bl.x) / rect_bl.width)
                    new_a := clamp(math.lerp(min_a, max_a, t), 0.3, math.PI - 0.3)

                    ball.vel = { math.cos(new_a), math.sin(new_a) } * s
                    ball.vel.y = -ball.vel.y
                    // SOUND
                }
            } else {
                rect_or := rl.Rectangle {
                    game.paddle_pos - f32(game.paddle_length / 2),
                    paddle_get_y(true) + 8,
                    f32(game.paddle_length),
                    8,
                }
                if rl.CheckCollisionRecs(rect_or, rect_ball) {
                    ball.vel.y = -ball.vel.y
                    a := linalg.atan2(ball.vel.y, ball.vel.x)
                    s := linalg.length(ball.vel)
                    min_a := a - 1.0
                    max_a := a + 1.0
                    t := 1.0 - math.saturate((ball.pos.x + 4 - rect_or.x) / rect_or.width)
                    new_a := clamp(math.lerp(min_a, max_a, t), 0.3, math.PI - 0.3)

                    ball.vel = { math.cos(new_a), math.sin(new_a) } * s
                    // SOUND
                }
            }
        } else {
            if ball.vel.x < 0 {
                rect_l := rl.Rectangle {
                    game.paddle_pos - f32(game.paddle_length / 2),
                    paddle_get_y(false),
                    8,
                    32,
                }
                if rl.CheckCollisionRecs(rect_l, rect_ball) {
                    ball.vel.x = -ball.vel.x
                    // SOUND
                }
            } else {
                rect_l := rl.Rectangle {
                    game.paddle_pos + f32(game.paddle_length / 2) - 8,
                    paddle_get_y(false),
                    8,
                    32,
                }
                if rl.CheckCollisionRecs(rect_l, rect_ball) {
                    ball.vel.x = -ball.vel.x
                    // SOUND
                }
            }
        }

        ball.pos += ball.vel

        for zone in death_zones {
            if rl.CheckCollisionRecs(rect_ball, zone) {
                ball.dead = true
                ball.dead_timer = 30
                // SOUND
            }
        }
    }

    // Board frame rendering
    {
        tile_bl := sprites[.Tiles_Blue]
        tile_or := sprites[.Tiles_Orange]
        src_tl := rl.Rectangle {
            0,
            0,
            TILE_SIZE,
            TILE_SIZE,
        }
        src_tr := rl.Rectangle {
            0,
            0,
            -TILE_SIZE,
            TILE_SIZE,
        }
        src_bl := rl.Rectangle {
            0,
            0,
            TILE_SIZE,
            -TILE_SIZE,
        }
        src_br := rl.Rectangle {
            0,
            0,
            -TILE_SIZE,
            -TILE_SIZE,
        }

        // Corners
        tl := [2]f32 {
            (RENDER_WIDTH - BOARD_WIDTH*TILE_SIZE) / 2,
            0,
        }
        tr := [2]f32 {
            tl.x + BOARD_WIDTH*TILE_SIZE,
            0,
        }
        bl := [2]f32 {
            tl.x,
            RENDER_HEIGHT - 8,
        }
        br := [2]f32 {
            tr.x,
            RENDER_HEIGHT - 8,
        }
        rl.DrawTextureRec(tile_bl, src_tl, tl - { TILE_SIZE, 0 }, rl.WHITE)
        rl.DrawTextureRec(tile_bl, src_tr, tr, rl.WHITE)
        rl.DrawTextureRec(tile_or, src_bl, bl - { TILE_SIZE, 0 }, rl.WHITE)
        rl.DrawTextureRec(tile_or, src_br, br, rl.WHITE)


        src_t := rl.Rectangle {
            TILE_SIZE,
            0,
            TILE_SIZE,
            TILE_SIZE,
        }
        src_b := rl.Rectangle {
            TILE_SIZE,
            0,
            TILE_SIZE,
            -TILE_SIZE,
        }

        // Top and bottom
        for i in 0..<BOARD_WIDTH {
            rl.DrawTextureRec(tile_bl, src_t, tl + { f32(i*TILE_SIZE), 0, }, rl.WHITE)
            rl.DrawTextureRec(tile_or, src_b, bl + { f32(i*TILE_SIZE), 0, }, rl.WHITE)
        }

        src_l := rl.Rectangle {
            0,
            TILE_SIZE,
            TILE_SIZE,
            TILE_SIZE,
        }
        src_r := rl.Rectangle {
            0,
            TILE_SIZE,
            -TILE_SIZE,
            TILE_SIZE,
        }

        // Left and right
        for i in 1..<BOARD_HEIGHT {
            rl.DrawTextureRec(tile_bl, src_l, tl + { -TILE_SIZE, f32(i*TILE_SIZE), }, rl.WHITE)
            rl.DrawTextureRec(tile_bl, src_r, tr + {          0, f32(i*TILE_SIZE), }, rl.WHITE)
            rl.DrawTextureRec(tile_or, src_l, bl + { -TILE_SIZE, -f32(i*TILE_SIZE), }, rl.WHITE)
            rl.DrawTextureRec(tile_or, src_r, br + {          0, -f32(i*TILE_SIZE), }, rl.WHITE)
        }
    }

    // Paddle rendering
    paddle_y := paddle_get_y(false)
    draw_paddle({ game.paddle_pos, paddle_y      }, int(game.paddle_anim*3), game.paddle_length, false)
    draw_paddle({ game.paddle_pos, paddle_y + 16 }, int(game.paddle_anim*3), game.paddle_length, true)

    // Ball rendering
    for ball in game.balls {
        texture: rl.Texture
        switch ball.color {
        case .Blue:
            texture = sprites[.Ball_Blue]
        case .Orange:
            texture = sprites[.Ball_Orange]
        }
        rl.DrawTextureV(texture, ball.pos, rl.WHITE)
    }

    rl.DrawRectangleRec(death_zones[0], rl.RED)
    rl.DrawRectangleRec(death_zones[1], rl.YELLOW)
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
