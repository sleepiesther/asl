state("EtG") { }

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "Enter the Gungeon";

    settings.Add("lvl-exit", true, "Split on level exit");
    settings.Add("lvl-secret", true, "Split on secret levels");
    settings.Add("boss-enter", false, "Split on boss intro");
    settings.Add("boss-exit", false, "Split on boss defeat");
    settings.Add("run-end", true, "Split on run completion");

    vars.Helper.AlertGameTime();
}

init
{
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        vars.Helper["Level"] = mono.Make<int>("GameManager", "mr_manager", "nextLevelIndex");
        vars.Helper["Paused"] = mono.Make<bool>("GameManager", "mr_manager", "m_paused");
        vars.Helper["Credits"] = mono.Make<bool>("TimeTubeCreditsController", "IsTimeTubing");

        vars.Helper["BossIntroRunning"] = mono.Make<bool>("GameManager", "IsBossIntro");
        vars.Helper["BossOutroRunning"] = mono.Make<bool>("BossKillCam", "BossDeathCamRunning");

        var sessionStats = mono.Make<IntPtr>("GameStatsManager", "m_instance", "m_sessionStats", "stats");
        vars.GetSessionStat = (Func<int, float>)(stat =>
        {
            sessionStats.Update(game);

            var count = vars.Helper.Read<int>(sessionStats.Current + 0x38);
            var keys = vars.Helper.ReadArray<int>(sessionStats.Current + 0x20);

            for (int i = 0; i < count; i++)
            {
                if (keys[i] == stat)
                {
                    return vars.Helper.Read<float>(sessionStats.Current + 0x28, 0x20 + sizeof(float) * i);
                }
            }

            return 0;
        });

        var savedSessionStats = mono.Make<IntPtr>("GameStatsManager", "m_instance", "m_savedSessionStats", "stats");
        vars.GetSavedSessionStat = (Func<int, float>)(stat =>
        {
            savedSessionStats.Update(game);

            var count = vars.Helper.Read<int>(savedSessionStats.Current + 0x38);
            var keys = vars.Helper.ReadArray<int>(savedSessionStats.Current + 0x20);

            for (int i = 0; i < count; i++)
            {
                if (keys[i] == stat)
                {
                    return vars.Helper.Read<float>(savedSessionStats.Current + 0x28, 0x20 + sizeof(float) * i);
                }
            }

            return 0;
        });

        return true;
    });
}

update
{
    if (current.Paused)
        return false;

    current.SecretRoomsFound = vars.GetSessionStat(5); // TrackedStats.SECRET_ROOMS_FOUND
    current.Igt = vars.GetSessionStat(23) + vars.GetSavedSessionStat(23); // TrackedStats.TIME_PLAYED
}

start
{
    return old.Igt < 0.01f && current.Igt >= 0.01f;
}

split
{
    return settings["lvl-exit"] && old.Level < current.Level && current.Level > 2
        || settings["lvl-secret"] && old.SecretRoomsFound < current.SecretRoomsFound
        || settings["boss-enter"] && !old.BossIntroRunning && current.BossIntroRunning
        || settings["boss-exit"] && old.BossOutroRunning && !current.BossOutroRunning
        || settings["run-end"] && old.Credits && !current.Credits;
}

reset
{
    return old.Igt > 0.01f && current.Igt <= 0.01f;
}

gameTime
{
    return TimeSpan.FromSeconds(current.Igt);
}

isLoading
{
    return true;
}

exit
{
    Func<bool> condition = () => settings.IsResetEnabled;
    vars.Helper.Timer.Reset(condition);
}
