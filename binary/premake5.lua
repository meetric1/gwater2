PROJECT_GENERATOR_VERSION = 3	-- 3 = 64 bit support

newoption({
	trigger = "gmcommon",
	description = "Sets the path to the garrysmod_common (https://github.com/danielga/garrysmod_common) directory",
	value = "./garrysmod_common",
	default = "./garrysmod_common"
})

newoption({
	trigger = "main",
	description = "Build for the GMod main (public) branch SDK; defines GMOD_MAIN and targets gmcl_gwater2_main_*"
})

local gmcommon = assert(_OPTIONS.gmcommon or os.getenv("GARRYSMOD_COMMON"),
	"you didn't provide a path to your garrysmod_common (https://github.com/danielga/garrysmod_common) directory")

include(gmcommon)

CreateWorkspace({name = "gwater2", abi_compatible = true, path = ""})
	--CreateProject({serverside = true, source_path = "source", manual_files = false})
	--	IncludeLuaShared()
	--	IncludeScanning()
	--	IncludeDetouring()
	--	IncludeSDKCommon()
	--	IncludeSDKTier0()
	--	IncludeSDKTier1()

	CreateProject({serverside = false, source_path = "src"})
		IncludeLuaShared()
		IncludeScanning()
		--IncludeDetouring()
		--IncludeSteamAPI()
		IncludeSDKCommon()
		IncludeSDKTier0()
		IncludeSDKTier1()
		IncludeSDKMathlib()

		includedirs {
			"FleX/include",
			"BSPParser",
			"GMFS",
			"src/sourceengine",
			"ThreadPool"
		}

		if _OPTIONS["main"] then
			defines { "GMOD_MAIN" }
			targetname("gmcl_gwater2_main")
		end

		files {
			"BSPParser/**",
			"GMFS/**",
			"src/sourceengine/*",
			"src/shaders/*"
		}

		filter({"system:windows", "platforms:x86"})
			targetsuffix("_win32")

			libdirs {
				"FleX/lib/win32",
			}

			links { 
				"NvFlexReleaseD3D_x86",
				"NvFlexExtReleaseD3D_x86",
			}

		filter({"system:windows", "platforms:x86_64"})
			targetsuffix("_win64")

			libdirs {
				"FleX/lib/win64",
			}

			links { 
				"NvFlexReleaseD3D_x64",
				"NvFlexExtReleaseD3D_x64",
			}

			if _OPTIONS["main"] then
				-- sourcesdk-minimal only sets these on its own static libs, but consumers need COMPILER_MSVC64 too
				defines { "COMPILER_MSVC64", "PLATFORM_64BITS", "WIN64" }
			end
			
		filter({"system:linux", "platforms:x86_64"})
			targetsuffix("_linux64")

			includedirs {
				--"/usr/local/cuda-9.2/include",
				--"/usr/local/cuda-9.2/extras/cupti/include",
			}

			libdirs {
				"FleX/lib/linux64",
				--"/usr/local/cuda-9.2/lib64"
				"src/cuda"
			}
			
			links { 
				":NvFlexReleaseCUDA_x64.a",
				":NvFlexExtReleaseCUDA_x64.a",
				--":NvFlexDebugCUDA_x64.a",
				--":NvFlexDeviceDebug_x64.a",
				--":NvFlexExtDebugCUDA_x64.a",
				"cudart_static",
			}
			
			defines {
				"DX_TO_GL_ABSTRACTION",
				"IsPlatformOpenGL()"
			}
