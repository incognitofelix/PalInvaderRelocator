# PalInvaderRelocator

A small UE4SS C++ mod for **Palworld** that moves a base's raid **invader spawn point**
(`BP_InvaderStartPoint_C`) to a fixed coordinate just outside the base.

Raids still trigger as normal — the attackers simply appear **outside** the walls and
have to path in, instead of spawning inside the base.

This is a personal, single-base mod. It is intentionally **not** part of
[PalModToolkit](https://github.com/incognitofelix/pal-mod-toolkit) (that's a general
diagnostic kit); this mod's coordinate is specific to one base.

## How it works

Every frame (throttled to once per second) the mod looks up the loaded
`BP_InvaderStartPoint_C` actors and teleports the one near the configured target onto
that target — but only if it isn't already there. Because it re-applies continuously,
it survives world-partition streaming (the point loads when you reach the base) and any
in-game reset. Raids are server-authoritative and UE4SS runs in the server process, so
the same mod works on a dedicated server.

> **Note:** whether the game reads the spawn point's position *live* at raid time still
> has to be confirmed in-game. Move it, trigger a raid, observe where invaders appear.

## Configure

Edit the `CONFIG` block at the top of [`src/main.cpp`](src/main.cpp):

| Constant | Meaning |
| --- | --- |
| `k_actor_class` | Actor class to relocate. |
| `k_target_x/y/z` | Target position (cm). Capture by standing on the spot just outside your wall and reading your position (e.g. PalModToolkit's Player Location tool). |
| `k_capture_radius_cm` | Only points within this distance of the target are moved, so other bases' spawns are left alone. |
| `k_placed_epsilon_cm` | Distance under which a point counts as "already placed". |
| `k_scan_interval` | How often to scan. |

## Build & deploy

Uses the same import-library build model as PalModToolkit and, by default, the **same**
`UE4SS.lib` (`--ue4ss_implib` defaults to the shared `_ue4ss_implib` folder). If you
don't have it yet, generate one from your installed `UE4SS.dll`:

```powershell
.\scripts\generate_import_lib.ps1 -Ue4ssDll "C:\...\Pal\Binaries\Win64\ue4ss\UE4SS.dll" -OutDir "C:\Users\felix\dev\palworld-modding\_ue4ss_implib"
```

Then:

```powershell
xmake build
xmake install -o "C:\...\Pal\Binaries\Win64\ue4ss\Mods"
```

This drops `Mods\PalInvaderRelocator\dlls\main.dll` plus an empty `enabled.txt`.

## License

MIT.
