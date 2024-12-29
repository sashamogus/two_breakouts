package two_breakouts

font_load := #load("fonts/PressStart2P-Regular.ttf")

Sprite_Tag :: enum {
    Ball_Blue,
    Ball_Orange,
    Block_Blue,
    Block_Orange,
    Tiles_Blue,
    Tiles_Orange,
    Paddle_Blue,
    Paddle_Orange,
    Item_M,
    Item_T,
    Item_L,
}

sprites_load := [Sprite_Tag][]byte {
    .Ball_Blue     = #load("sprites/ball_blue.png"),
    .Ball_Orange   = #load("sprites/ball_orange.png"),
    .Block_Blue    = #load("sprites/block_blue.png"),
    .Block_Orange  = #load("sprites/block_orange.png"),
    .Tiles_Blue    = #load("sprites/tiles_blue.png"),
    .Tiles_Orange  = #load("sprites/tiles_orange.png"),
    .Paddle_Blue   = #load("sprites/paddle_blue.png"),
    .Paddle_Orange = #load("sprites/paddle_orange.png"),
    .Item_M = #load("sprites/Item_M.png"),
    .Item_T = #load("sprites/Item_T.png"),
    .Item_L = #load("sprites/Item_L.png"),
}

