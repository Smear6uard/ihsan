# The haptic vocabulary

Five things the app is allowed to say through the Taptic Engine, and
nothing else. Every one of them is defined in
`ihsan/Today/Helpers/Haptics.swift`; nothing constructs a feedback
generator anywhere else.

| Call | Feel | What it means | Where |
| --- | --- | --- | --- |
| `settle()` | one soft impact, 0.85 intensity | **A worship commit.** Something was recorded. | prayer log, fast, nafl, dhikr boundary, qibla alignment |
| `impact(.light)` / `tap()` | one light impact | Navigation, selection, opening a thing | rows, chips, markers, tabs, steppers |
| `impact(.medium)` | one medium impact | A deliberate action that is work to undo | enabling pause or travel, resetting, clearing |
| `notification(.warning)` | the system's warning pattern | Something failed and the person should know | permission denied, save failed, no results |
| `notification(.success)` / `success()` | the system's rising double-tap | An **operation** finished — never worship | data export, delete-all, setup completion |

## The settle

> One soft impact, and the only haptic a worship commit ever makes.
>
> Every act the app records — a prayer logged from any surface, a fast,
> a dhikr boundary, the qibla coming into alignment — is the same
> physical event under the thumb: a small weight coming to rest. Not a
> click, which reads as a machine acknowledging input, and not a success
> notification's rising double-tap, which reads as praise. Worship is
> recorded, not applauded.
>
> Soft rather than light because the commit is the heaviest thing a
> person does here, and it should feel like it landed.

This is the rule the app is most likely to break by accident, because
`Haptics.success()` is right there and reads as "it worked". Before this
pass, five different worship commits made five different sounds:

| Commit | Was | Now |
| --- | --- | --- |
| Log sheet | `notification(.success)` | `settle()` |
| Focused card | `success()` | `settle()` |
| Nafl chip | `impact(.soft)` | `settle()` |
| Fast | `impact(.light)` | `settle()` |
| Dhikr cycle boundary | `notification(.success)` | `settle()` |
| Qibla alignment | `impact(.soft)` | `settle()` |
| Yesterday's sheet | — | `settle()` |

The dhikr instrument is the one place with a second, quieter haptic
underneath: each bead is `impact(.light)` so the boundary is felt as an
arrival rather than as one more of the same.

`HapticVocabularyTests` reads the sources and fails if a worship surface
reaches for a success notification, or if a new file starts building
feedback generators of its own.

## Where haptics are not

- **Never on a value changing by itself.** A countdown ticking, a
  window opening, a palette drifting: the app does not tap someone on
  the shoulder for the passage of time.
- **Never on a notification arriving.** iOS owns that.
- **Never repeated.** One event, one haptic. The qibla's alignment is
  rate-limited to a single arrival per approach.
- **Never in place of a visual.** Nothing is communicated by haptic
  alone; every one accompanies something on screen.
