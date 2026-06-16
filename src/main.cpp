// PalInvaderRelocator -- moves base-raid invader spawn points to a fixed coordinate
// just outside the base, so raids still trigger but the attackers no longer appear
// inside the walls.
//
// How it works: every frame (throttled) it looks up the invader start-point actors
// currently loaded and, for the one belonging to this base, teleports it to the
// configured target. It re-applies automatically whenever the point streams in or the
// game resets it. Server-authoritative: raids are decided server-side, and UE4SS runs
// in the server process, so this runs there too.
//
// Build model: links against the installed UE4SS.dll via an import library, exactly
// like the PalModToolkit project (they share the same _ue4ss_implib). See README.md.

// UE4SS / Unreal headers. Order matters: CppUserModBase pulls in the global UE4SS
// config that DynamicOutput's formatting macros rely on, so include it first.
#include <Mod/CppUserModBase.hpp>
#include <DynamicOutput/DynamicOutput.hpp>
#include <Unreal/UObjectGlobals.hpp>
#include <Unreal/AActor.hpp>
#include <Unreal/UnrealCoreStructs.hpp>
#include <Unreal/FHitResult.hpp>

#include <chrono>
#include <vector>

using namespace RC;
using namespace RC::Unreal;

namespace
{
    // =========================================================================
    //  CONFIG -- edit these for your base.
    // =========================================================================

    // Actor class to relocate. Base-raid invaders spawn at BP_InvaderStartPoint_C.
    const auto k_actor_class = STR("BP_InvaderStartPoint_C");

    // Where to park it: a spot just OUTSIDE your base wall, near enough that raiders
    // still path in. Capture it by standing on the spot and reading your position
    // (e.g. PalModToolkit's Player Location tool).
    constexpr double k_target_x = -72956.12;
    constexpr double k_target_y =  191290.96;
    constexpr double k_target_z =    2577.70;

    // Only relocate points within this distance (cm) of the target, so this moves
    // *your* base's point and never a different base's spawn elsewhere on the map.
    constexpr double k_capture_radius_cm = 20000.0;   // 200 m

    // Treat a point as already placed within this distance (cm) of the target.
    constexpr double k_placed_epsilon_cm = 100.0;     // 1 m

    // FindAllOf is too heavy to run every frame; scan at most this often.
    constexpr auto k_scan_interval = std::chrono::seconds(1);

    // =========================================================================
}

class PalInvaderRelocator : public CppUserModBase
{
public:
    PalInvaderRelocator()
    {
        ModName        = STR("PalInvaderRelocator");
        ModVersion     = STR("0.1.0");
        ModDescription = STR("Moves base-raid invader spawns just outside the base.");
        ModAuthors     = STR("felix");

        Output::send<LogLevel::Verbose>(STR("[PalInvaderRelocator] v0.1.0 loaded.\n"));
    }

    // Called once per frame by UE4SS.
    auto on_update() -> void override
    {
        // 1) Throttle: only scan once per interval.
        const auto now = std::chrono::steady_clock::now();
        if (now - m_last_scan < k_scan_interval)
        {
            return;
        }
        m_last_scan = now;

        // 2) Every invader start point currently loaded. (If this ever comes back
        //    empty even at the base, the fallback is FindAllOf("Actor") + a name
        //    filter on GetFullName(), the way PalModToolkit's Nearby Actors works.)
        std::vector<UObject*> points;
        UObjectGlobals::FindAllOf(k_actor_class, points);
        if (points.empty())
        {
            return;
        }

        const FVector target(k_target_x, k_target_y, k_target_z);
        constexpr double epsilon_sq = k_placed_epsilon_cm * k_placed_epsilon_cm;
        constexpr double capture_sq = k_capture_radius_cm * k_capture_radius_cm;

        // 3) Park the base's point at the target -- but only if it isn't already there
        //    (keeps the log quiet and avoids a redundant teleport every second).
        for (auto* obj : points)
        {
            auto* actor = static_cast<AActor*>(obj);
            const FVector pos = actor->K2_GetActorLocation();

            const double dx = pos.X() - target.X();
            const double dy = pos.Y() - target.Y();
            const double dz = pos.Z() - target.Z();
            const double dist_sq = dx * dx + dy * dy + dz * dz;

            if (dist_sq <= epsilon_sq) { continue; }  // already parked
            if (dist_sq >  capture_sq) { continue; }  // belongs to another base

            // bSweep=false + bTeleport=true: set position only, ignore collision,
            // leave the point's rotation untouched.
            FHitResult hit{};
            actor->K2_SetActorLocation(target, false, hit, true);

            Output::send<LogLevel::Warning>(
                STR("[PalInvaderRelocator] Relocated {} -> X={} Y={} Z={}\n"),
                obj->GetFullName(), target.X(), target.Y(), target.Z());
        }
    }

private:
    std::chrono::steady_clock::time_point m_last_scan{};
};

// ---- UE4SS C++ mod entry points ----
#define PIR_API __declspec(dllexport)
extern "C"
{
    PIR_API RC::CppUserModBase* start_mod()
    {
        return new PalInvaderRelocator();
    }

    PIR_API void uninstall_mod(RC::CppUserModBase* mod)
    {
        delete mod;
    }
}
