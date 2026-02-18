if not game then script = require "test/relative-string" end
local typeof = game and typeof or require "test/mock".typeof:: never
local Instance = game and Instance or require "test/mock".Instance :: never

local throw = require(script.Parent.throw)
local defaults = require(script.Parent.defaults)
local apply = require(script.Parent.apply)

local ctor_cache = {} :: { [string]: () -> Instance }

setmetatable(ctor_cache :: any, {
    __index = function(self, class)
        local ok, instance: Instance = pcall(Instance.new, class :: any)
        if not ok then throw(`invalid class name, could not create instance of class { class }`) end

        local default: { [string]: unknown }? = defaults[class]
        if default then
            for i, v in next, default do
                (instance :: any)[i] = v
            end
        end

        local function ctor(properties: Props): Instance
            return apply(instance:Clone(), properties)    
        end  

        self[class] = ctor
        return ctor
    end
})

local function create_instance(class: string)
    return ctor_cache[class]
end

local function clone_instance(instance: Instance)
    return function(properties: Props): Instance
        local clone = instance:Clone()
        if not clone then throw "attempt to clone a non-archivable instance" end
        return apply(clone, properties)
    end
end

local function create(class_or_instance: string|Instance): (Props) -> Instance
    if type(class_or_instance) == "string" then
        return create_instance(class_or_instance)
    elseif typeof(class_or_instance) == "Instance" then
        return clone_instance(class_or_instance)
    else
        throw("bad argument #1, expected string or instance, got " .. typeof(class_or_instance))
        return nil :: never
    end
end

type Props = { [any]: any }
return (create :: any) :: 
( <T>(T & Instance) -> (Props) -> T ) &
( ("Folder") -> (Props) -> Folder ) &
( ("BillboardGui") -> (Props) -> BillboardGui ) &
( ("CanvasGroup") -> (Props) -> CanvasGroup ) &
( ("Frame") -> (Props) -> Frame ) &
( ("ImageButton") -> (Props) -> ImageButton ) &
( ("ImageLabel") -> (Props) -> ImageLabel ) &
( ("ScreenGui") -> (Props) -> ScreenGui ) &
( ("ScrollingFrame") -> (Props) -> ScrollingFrame ) &
( ("SurfaceGui") -> (Props) -> SurfaceGui ) &
( ("TextBox") -> (Props) -> TextBox ) &
( ("TextButton") -> (Props) -> TextButton ) &
( ("TextLabel") -> (Props) -> TextLabel ) &
( ("UIAspectRatioConstraint") -> (Props) -> UIAspectRatioConstraint ) &
( ("UICorner") -> (Props) -> UICorner ) &
( ("UIGradient") -> (Props) -> UIGradient ) &
( ("UIGridLayout") -> (Props) -> UIGridLayout ) &
( ("UIListLayout") -> (Props) -> UIListLayout ) &
( ("UIPadding") -> (Props) -> UIPadding ) &
( ("UIPageLayout") -> (Props) -> UIPageLayout ) &
( ("UIScale") -> (Props) -> UIScale ) &
( ("UISizeConstraint") -> (Props) -> UISizeConstraint ) &
( ("UIStroke") -> (Props) -> UIStroke ) &
( ("UITableLayout") -> (Props) -> UITableLayout ) &
( ("UITextSizeConstraint") -> (Props) -> UITextSizeConstraint ) &
( ("VideoFrame") -> (Props) -> VideoFrame ) &
( ("ViewportFrame") -> (Props) -> ViewportFrame ) &
( (string) -> (Props) -> Instance )
