--!strict

local wostween = require("tween") :: any

local TweenInfo = {}
local Tween = { FrameRate = 60 }
local TweenObject = {}
TweenObject.__index = TweenObject

export type Tweenable = number | boolean | Color3 | UDim | UDim2 | Vector2
export type TweenProperties = { [string]: Tweenable }

export type WoSTween = typeof(setmetatable(
    {} :: {
        Instance: Instance,
        TweenInfo: WoSTweenInfo,
        PlaybackState: Enum.PlaybackState,
        Properties: TweenProperties,

        _startProperties: TweenProperties,
        _currentRepeat: number,
        _direction: number,
        _alpha: number,
    },
    {} :: {
        __index: {
            Play: (self: WoSTween) -> (),
            Cancel: (self: WoSTween) -> (),
            Pause: (self: WoSTween) -> (),
            Reset: (self: WoSTween) -> (),
        },
    }
))

export type WoSTweenInfo = {
    Time: number,
    EasingStyle: Enum.EasingStyle,
    EasingDirection: Enum.EasingDirection,
    DelayTime: number,
    Reverses: boolean,
    RepeatCount: number | true,
    Looped: boolean,
}

local isUpdateLoopRunning = false
local currentlyPlayingTweens: { [WoSTween]: number } = {}
local playingTweenCount = 0

local function lerp(start: number, target: number, alpha: number)
    return start + alpha * (target - start)
end

local function tweenNumber(
    start: number,
    target: number,
    alpha: number,
    info: WoSTweenInfo
)
    return if start ~= target
        then lerp(
            start,
            target,
            wostween:GetValue(alpha, info.EasingStyle, info.EasingDirection)
        )
        else start
end

local function tweenUdim(
    start: UDim,
    target: UDim,
    alpha: number,
    tweenInfo: WoSTweenInfo
)
    local startScale, targetScale = start.Scale, target.Scale
    local startOffset, targetOffset = start.Offset, target.Offset
    return UDim.new(
        if startScale == targetScale
            then startScale
            else tweenNumber(startScale, targetScale, alpha, tweenInfo),
        if startOffset == targetOffset
            then startOffset
            else tweenNumber(startOffset, targetOffset, alpha, tweenInfo)
    )
end

local function updateTween(deltaTime: number)
    local playingTweens = currentlyPlayingTweens
    for tween, delayTime in playingTweens do
        if delayTime > 0 then
            delayTime = playingTweens[tween] - deltaTime
            playingTweens[tween] = math.max(delayTime, 0)
            tween.PlaybackState = Enum.PlaybackState.Delayed
            continue
        end

        tween.PlaybackState = Enum.PlaybackState.Playing

        local tweenInfo = tween.TweenInfo
        local object = tween.Instance

        local properties = tween.Properties
        local startProperties = tween._startProperties

        local step = (deltaTime - delayTime) / tweenInfo.Time
        local rawAlpha = tween._alpha + step * tween._direction
        local alpha = math.clamp(rawAlpha, 0, 1)

        local alphaOverflow = math.abs(rawAlpha - alpha)
        tween._alpha = alpha

        for property, startValue in startProperties do
            (object :: any)[property] = Tween.TweenValue(
                startValue,
                properties[property],
                alpha,
                tweenInfo
            )
        end

        if alpha == 0 or alpha == 1 then
            local reverses = tweenInfo.Reverses
            if (reverses and tween._direction == -1) or not reverses then
                tween._currentRepeat += 1
            end

            if
                not tweenInfo.Looped
                and tween._currentRepeat
                    >= (tweenInfo.RepeatCount :: number) + 1
            then
                currentlyPlayingTweens[tween] = nil
                playingTweenCount -= 1
                tween.PlaybackState = Enum.PlaybackState.Completed

                table.clear(startProperties)
                tween._alpha = 0
                tween._direction = 1
            elseif reverses then
                tween._direction *= -1
                currentlyPlayingTweens[tween] = tweenInfo.DelayTime
                    - alphaOverflow * tween._direction
            else
                tween._alpha = alphaOverflow
                for property, value in startProperties do
                    (object :: any)[property] = value
                end
            end
        end
    end
end

local function loopTween()
    if isUpdateLoopRunning then return end
    isUpdateLoopRunning = true

    task.spawn(function()
        local excess = 0
        while playingTweenCount > 0 do
            local deltaTime = task.wait(1 / Tween.FrameRate)
            local startTime = os.clock()

            updateTween(deltaTime + excess)
            excess = os.clock() - startTime
        end
        isUpdateLoopRunning = false
    end)
end

local VALID_DATATYPES = {
    ["number"] = true,
    ["boolean"] = true,
    ["Color3"] = true,
    ["UDim"] = true,
    ["UDim2"] = true,
    ["Vector2"] = true,
}

local TWEEN_FUNCTIONS: {
    [string]: (
        start: any,
        target: any,
        alpha: number,
        tweenInfo: WoSTweenInfo
    ) -> any,
} =
    {
        number = tweenNumber,
        boolean = function(
            start: boolean,
            target: boolean,
            alpha,
            tweenInfo
        )
            return if start ~= target
                then start
                else (wostween:GetValue(
                    alpha,
                    tweenInfo.EasingStyle,
                    tweenInfo.EasingDirection
                ) <= 0.5) == start
        end,
        Color3 = function(
            startValue: Color3,
            targetValue: Color3,
            alpha,
            tweenInfo
        )
            return Color3.new(
                math.clamp(
                    tweenNumber(startValue.R, targetValue.R, alpha, tweenInfo),
                    0,
                    1
                ),
                math.clamp(
                    tweenNumber(startValue.G, targetValue.G, alpha, tweenInfo),
                    0,
                    1
                ),
                math.clamp(
                    tweenNumber(startValue.B, targetValue.B, alpha, tweenInfo),
                    0,
                    1
                )
            )
        end,
        UDim = tweenUdim,
        UDim2 = function(
            startValue: UDim2,
            targetValue: UDim2,
            alpha,
            tweenInfo
        )
            local x1, y1 = startValue.X, startValue.Y
            local x2, y2 = targetValue.X, targetValue.Y

            return UDim2.new(
                if x1 == x2 then x1 else tweenUdim(x1, x2, alpha, tweenInfo),
                if y1 == y2 then y1 else tweenUdim(y1, y2, alpha, tweenInfo)
            )
        end,
        Vector2 = function(
            startValue: Vector2,
            targetValue: Vector2,
            alpha,
            tweenInfo
        )
            return Vector2.new(
                tweenNumber(startValue.X, targetValue.X, alpha, tweenInfo),
                tweenNumber(startValue.Y, targetValue.Y, alpha, tweenInfo)
            )
        end,
    }

function TweenInfo.new(
    time: number?,
    easingStyle: Enum.EasingStyle?,
    easingDirection: Enum.EasingDirection?,
    delayTime: number?,
    reverses: boolean?,
    repeatCount: (number | true)?
): WoSTweenInfo
    local isLooped = repeatCount == true
        or repeatCount == math.huge
        or (typeof(repeatCount) == "number" and repeatCount < 0)

    return {
        Time = time or 1,
        EasingStyle = easingStyle or Enum.EasingStyle.Quad,
        EasingDirection = easingDirection or Enum.EasingDirection.Out,
        DelayTime = delayTime or 0,
        Reverses = reverses == true,
        RepeatCount = if isLooped then 0 else repeatCount or 0,
        Looped = isLooped,
    } :: any
end

function Tween.new(
    instance: any,
    properties: TweenProperties,
    tweenInfo: WoSTweenInfo
): WoSTween
    for property, targetValue in properties do
        local currentType = typeof(instance[property])
        local targetType = typeof(targetValue)

        if not VALID_DATATYPES[currentType] then
            error(
                `The current value of {property} is untweenable ({currentType}).`
            )
        elseif currentType ~= targetType then
            error(
                `Type mismatch for property {property}, current value is of the type {currentType}, target is of the type {targetType}.`
            )
        end
    end

    return setmetatable({
        Instance = instance,
        TweenInfo = tweenInfo,
        PlaybackState = Enum.PlaybackState.Begin,
        Properties = properties,

        _startProperties = {},
        _currentRepeat = 0,
        _direction = 1,
        _alpha = 0,
    }, TweenObject) :: any
end

function Tween.TweenValue<T>(
    start: T,
    target: T,
    alpha: number,
    tweenInfo: WoSTweenInfo
): T
    return TWEEN_FUNCTIONS[typeof(target)](start, target, alpha, tweenInfo)
end

function Tween.GetValue(
    alpha: number,
    easingStyle: Enum.EasingStyle,
    easingDirection: Enum.EasingDirection
)
    return wostween:GetValue(alpha, easingStyle, easingDirection)
end

function TweenObject.Play(self: WoSTween)
    if currentlyPlayingTweens[self] then return end
    local totalProperties = 0

    for property, targetProperty in self.Properties do
        local currentProperty = (self.Instance :: any)[property]
        if targetProperty == currentProperty then continue end
        self._startProperties[property] = currentProperty
        totalProperties += 1
    end

    if totalProperties == 0 then return end
    currentlyPlayingTweens[self] = self.TweenInfo.DelayTime
    playingTweenCount += 1
    loopTween()
end

function TweenObject.Cancel(self: WoSTween)
    if not currentlyPlayingTweens[self] then return end

    self.PlaybackState = Enum.PlaybackState.Cancelled

    currentlyPlayingTweens[self] = nil
    playingTweenCount -= 1

    table.clear(self._startProperties)
    self._alpha = 0
end

function TweenObject.Pause(self: WoSTween)
    if not currentlyPlayingTweens[self] then return end

    self.PlaybackState = Enum.PlaybackState.Paused
    currentlyPlayingTweens[self] = nil
    playingTweenCount -= 1
end

function TweenObject.Reset(self: WoSTween)
    for property, value in self._startProperties do
        (self.Instance :: any)[property] = value
    end
    self._alpha = 0
end

return { Tween = Tween, TweenInfo = TweenInfo }

--[[ EOF ]]
--
