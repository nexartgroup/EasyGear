-- Loading and booting the addon in the modelled client
return function(T)
    T.test("addon loads and boots", function()
        local W = T.world()
        T.ok(W.env.EasyGear, "global EasyGear")
        T.eq(W.EG.isForever, true)
        T.eq(W.EG.version, "4.0.0-test")
        T.ok(W.EG.Window and W.EG.ProfileWindow and W.EG.Options and W.EG.Slash, "modules")
        T.has(W.chatText(), "EasyGear 4.0.0-test loaded.")
    end)
end
