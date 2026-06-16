-- PalInvaderRelocator -- a single-purpose UE4SS C++ mod for Palworld that moves
-- base-raid invader spawn points just outside the base.
--
-- Build model: we do NOT recompile UE4SS. We compile against the UE4SS headers and
-- LINK against an import library generated from the UE4SS.dll the game already loads
-- (see scripts/generate_import_lib.ps1). This guarantees an exact ABI match with the
-- installed DLL. By default it reuses the same import lib as the PalModToolkit project.
--
-- Two paths are configurable (see `xmake f --help`):
--   --ue4ss_src    : the RE-UE4SS source tree (for headers)
--   --ue4ss_implib : folder containing the generated UE4SS.lib
-- Third-party package headers/libs (fmt, imgui, ...) are discovered dynamically from
-- xmake's package cache, so no machine-specific hashes are hard-coded.

set_xmakever("2.9.3")
add_rules("mode.release", "mode.releasedbg")
set_allowedplats("windows")
set_allowedarchs("x64")
set_defaultmode("release")

option("ue4ss_src")
    set_default("C:/Users/felix/dev/palworld-modding/RE-UE4SS")
    set_showmenu(true)
    set_description("Path to the RE-UE4SS source tree (provides the C++ headers).")
option_end()

option("ue4ss_implib")
    set_default("C:/Users/felix/dev/palworld-modding/_ue4ss_implib")
    set_showmenu(true)
    set_description("Folder containing the generated UE4SS.lib import library.")
option_end()

-- First-party include dirs, relative to the UE4SS source tree.
local UE4SS_FIRST_PARTY = {
    "UE4SS/include", "UE4SS/generated_include",
    "deps/first/Unreal/include", "deps/first/Unreal/generated_include",
    "deps/first/Unreal/include/Unreal", "deps/first/Unreal/include/Unreal/Core",
    "deps/first/ASMHelper/include", "deps/first/SinglePassSigScanner/include",
    "deps/first/LuaMadeSimple/include", "deps/first/LuaRaw/include",
    "deps/first/Function/include", "deps/first/IniParser/include",
    "deps/first/JSON/include", "deps/first/ParserBase/include",
    "deps/first/Input/include", "deps/first/DynamicOutput/include",
    "deps/first/File/include", "deps/first/Constructs/include",
    "deps/first/Helpers/include", "deps/first/String/include",
    "deps/first/MProgram/include", "deps/first/ScopedTimer/include",
    "deps/first/Profiler/include", "deps/third/glad/include",
}

-- Third-party packages we need headers from (discovered by name, any version/hash).
local UE4SS_PACKAGES = {
    "i/imgui", "g/glfw", "i/imguitextedit", "i/iconfontcppheaders",
    "g/glaze", "p/polyhook_2", "z/zydis", "z/zycore",
}

-- fmt is version-sensitive: DynamicOutput uses fmt::buffered_context (fmt 11+). Pin to
-- the version this UE4SS source requires so an older cached fmt cannot break the build.
local FMT_VERSION = "11.2.0"

local UE4SS_DEFINES = {
    "WINVER=0x0A00", "_WIN32_WINNT=0x0A00", "_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR=1",
    "UE4SS_LIB_VERSION_MAJOR=3", "UE4SS_LIB_VERSION_MINOR=0", "UE4SS_LIB_VERSION_HOTFIX=1",
    "UE4SS_LIB_VERSION_PRERELEASE=0", "UE4SS_LIB_VERSION_BETA=0",
    "UE4SS_LIB_BETA_STARTED=1", "UE4SS_LIB_IS_BETA=1",
    "GLFW_INCLUDE_NONE", "ZYDIS_STATIC_BUILD", "ZYCORE_STATIC_BUILD",
    "IS_TRACY=0", "IS_SUPERLUMINAL=0", "DISABLE_PROFILER",
    "UE_GAME", "UE_BUILD_SHIPPING", "PLATFORM_WINDOWS", "PLATFORM_MICROSOFT",
    "OVERRIDE_PLATFORM_HEADER_NAME=Windows", "UBT_COMPILED_PLATFORM=Win64",
    "UNICODE", "_UNICODE",
}

target("PalInvaderRelocator")
    set_kind("shared")
    set_languages("cxx23")
    set_runtimes("MD")
    set_exceptions("cxx")
    set_basename("main") -- UE4SS loads "main.dll"

    add_includedirs("src")
    add_files("src/**.cpp")

    add_defines(UE4SS_DEFINES)
    add_cxflags("/utf-8", "/Zc:inline", "/Zc:strictStrings", "/Zc:preprocessor", {force = true})

    on_load(function (target)
        local src = get_config("ue4ss_src")
        for _, d in ipairs(UE4SS_FIRST_PARTY) do
            target:add("includedirs", path.join(src, d))
        end

        local pkgroot = path.join(os.getenv("LOCALAPPDATA"), ".xmake", "packages")
        for _, name in ipairs(UE4SS_PACKAGES) do
            -- structure: <pkgroot>/<letter>/<name>/<version>/<hash>/include
            for _, inc in ipairs(os.dirs(path.join(pkgroot, name, "*", "*", "include"))) do
                target:add("includedirs", inc)
            end
        end
        -- imgui keeps some headers one level deeper.
        for _, inc in ipairs(os.dirs(path.join(pkgroot, "i/imgui", "*", "*", "include/imgui"))) do
            target:add("includedirs", inc)
        end

        -- fmt: version-pinned headers + its compiled static lib (number formatting,
        -- which UE4SS.dll does not export).
        for _, inc in ipairs(os.dirs(path.join(pkgroot, "f/fmt", FMT_VERSION, "*", "include"))) do
            target:add("includedirs", inc)
        end
        for _, lib in ipairs(os.dirs(path.join(pkgroot, "f/fmt", FMT_VERSION, "*", "lib"))) do
            target:add("linkdirs", lib)
        end
        target:add("links", "fmt")

        -- The import library for the installed UE4SS.dll.
        target:add("linkdirs", get_config("ue4ss_implib"))
        target:add("links", "UE4SS")
    end)

    -- Convenience: `xmake install -o <ue4ss/Mods dir>` drops main.dll into place.
    on_install(function (target)
        local installdir = target:installdir() or "$(buildir)/install"
        local moddir = path.join(installdir, target:name(), "dlls")
        os.mkdir(moddir)
        os.cp(target:targetfile(), path.join(moddir, "main.dll"))
        local enabled = path.join(installdir, target:name(), "enabled.txt")
        if not os.exists(enabled) then io.writefile(enabled, "") end
    end)
