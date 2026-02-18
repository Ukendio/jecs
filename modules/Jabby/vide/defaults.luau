local Enum = game and Enum or require "test/mock".Enum :: never
local Color3 = game and Color3 or require "test/mock".Color3 :: never
local Vector3 = game and Vector3 or require "test/mock".Vector3 :: never

return {
    Part = {
        Material = Enum.Material.SmoothPlastic,
        Size = Vector3.new(1, 1, 1),
        Anchored = true
    },

    BillboardGui = {
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    },

    CanvasGroup = nil,

    Frame = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0
    },

    ImageButton = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        AutoButtonColor = false
    },

    ImageLabel = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
    },

    ScreenGui = {
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    },

    ScrollingFrame = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        ScrollBarImageColor3 = Color3.new(0, 0, 0)
    },
    
    SurfaceGui = {
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

        PixelsPerStud = 50,
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    },
    
    TextBox = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.SourceSans,
        Text = "",
        TextColor3 = Color3.new(0, 0, 0)
    },

    TextButton = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.SourceSans,
        Text = "",
        TextColor3 = Color3.new(0, 0, 0)
    },
    
    TextLabel = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Font = Enum.Font.SourceSans,
        Text = "",
        TextColor3 = Color3.new(0, 0, 0)
    },
    
    UIListLayout = {
        SortOrder = Enum.SortOrder.LayoutOrder
    },
   
    UIGridLayout = {
        SortOrder = Enum.SortOrder.LayoutOrder
    },

    UITableLayout = {
        SortOrder = Enum.SortOrder.LayoutOrder
    },

    UIPageLayout = {
        SortOrder = Enum.SortOrder.LayoutOrder
    },
    
    VideoFrame = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0
    },
    
    ViewportFrame = {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0
    }
}
