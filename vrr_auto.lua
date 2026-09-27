-- 设定你的显示器物理最大刷新率 (240Hz)
local max_display_fps = 237.0

function auto_vrr_multiplier()
    -- 获取当前视频的原始容器帧率 (例如 23.976 或 25)
    local fps = mp.get_property_number("container-fps", 0)
    
    -- 只处理大于 10 帧且小于最大刷新率一半的视频
    if fps > 10 and fps < (max_display_fps / 2) then
        -- 计算最接近 240 且不超过 240 的完美整数倍率 (例如 240 / 23.976 = 10.01 -> 取整为 10)
        local multiplier = math.floor(max_display_fps / fps)
        
        -- 计算出最终要输出的目标帧率 (例如 23.976 * 10 = 239.76 fps)
        local target_fps = fps * multiplier
        
        -- 强制向 mpv 写入 fps 视频滤镜，进行硬复制倍帧
        local filter_string = string.format("@vrr_fps:fps=fps=%f:round=near", target_fps)
        mp.commandv("vf", "add", filter_string)
        
        mp.msg.info(string.format("VRR 自动倍帧: 原始 %.3f fps -> 放大 %d 倍 -> 输出目标 %.3f fps", fps, multiplier, target_fps))
    else
		mp.msg.info("已是高帧率 无需倍帧")
        -- 如果视频本身就已经是高帧率 (>120fps)，则不进行任何倍帧，清空滤镜
        mp.commandv("vf", "remove", "@vrr_fps")
    end
end


local function on_vf_changed(name, vf_string)
    -- 如果 vf_string 是空字符串 ""，说明所有滤镜都被清空了
    if vf_string == "" then
        
        -- 【关键防抖机制】如果已经有一个定时器在倒计时，先取消它
        if vf_check_timer ~= nil then
            vf_check_timer:kill()
        end
        
        -- 设置 0.3 秒的延时后再去加载 VRR 滤镜
        vf_check_timer = mp.add_timeout(1, auto_vrr_multiplier)
        
    else
        -- 如果发现 vf 不是空的（比如你刚刚成功挂载了 VRR 或者 RIFE），清除定时器
        if vf_check_timer ~= nil then
            vf_check_timer:kill()
            vf_check_timer = nil
        end
    end
end

-- 在每次视频加载完毕后运行此脚本
--mp.register_event("file-loaded", auto_vrr_multiplier)
mp.observe_property("vf", "string", on_vf_changed)