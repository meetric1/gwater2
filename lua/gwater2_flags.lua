-- flags file. something like feature flags to turn on / off certain things
-- in lua part of gwater2

-- whether to load stub instead of actual module
-- useful for testing lua side of gw2 on native linux gmod
local toload = (BRANCH == "x86-64" or BRANCH == "chromium") and "gwater2" or "gwater2_main" -- carrying
GWATER2_USE_STUB = not util.IsBinaryModuleInstalled(toload) and (system.IsLinux() or system.IsOSX())