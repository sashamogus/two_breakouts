package two_breakouts

import "core:os"
import "core:fmt"
import rl "vendor:raylib"

RENDER_WIDTH  :: 320
RENDER_HEIGHT :: 240

WINDOW_WIDTH :: RENDER_WIDTH
WINDOW_HEIGHT :: RENDER_HEIGHT

main :: proc() {
    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.SetTargetFPS(60)

    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "2 Breakouts! 🕹")
    windowed_width := rl.GetScreenWidth()
    windowed_height := rl.GetScreenHeight()

    render_texture := rl.LoadRenderTexture(RENDER_WIDTH, RENDER_HEIGHT)
    if !rl.IsRenderTextureValid(render_texture) {
        fmt.eprint("Render texture failed to initialize!!")
        os.exit(-1)
    }



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

        rl.BeginTextureMode(render_texture)
        rl.ClearBackground(rl.BLACK)
        for i in 0..<RENDER_WIDTH / 16 {
            for j in 0..<RENDER_HEIGHT / 16 {
                x := i32(16*i)
                y := i32(16*j)
                w := i32(15)
                h := i32(15)
                color: rl.Color
                color = u8(i + j)*16
                rl.DrawRectangle(x, y, w, h, color)
            }
        }
        rl.EndTextureMode()

        {
            src := rl.Rectangle {
                0,
                0,
                RENDER_WIDTH,
                -RENDER_HEIGHT,
            }

            res := [2]f32 { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
            scale := min(res.x / RENDER_WIDTH, res.y / RENDER_HEIGHT)
            dst_res := [2]f32 { RENDER_WIDTH * scale, RENDER_HEIGHT * scale }
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
