# Stone sentinel independent map idle

2026-10-02. Agent-reviewed `map_idle`: four 6 FPS looping frames, 256×256 with anchor (128,224), no gameplay events/pose holds. Native source remains draft; human signoff false.

One new built-in transparent imagegen atlas and exact actual prompt are retained. It paints an independent elevated front camera with exposed top stone planes. Weathered stone chest/head, teal recesses, moss cracks, fist arm and fused shield arm preserve the accepted sentinel identity. Nine painted layers plus six explicit elbow/knee/contact nodes are editable in the native scene; full map limb layers remain rigid segments for planted idle. This is not a walking or fully joint-flexing battle rig.

Review viewed final body and combined four-pose contacts, browser original/quarter playback, numbered 0–3 pose selection, all 26/33/47px thumbnails and effect off/on. Head and both arms move independently with fixed legs; dark stone overlap closes neck/shoulders. The body remains identifiable without the subtle optional teal-groove overlay. Initial atlas neighbor crumbs were removed by transparent component extraction; rejected contact is retained. Source RGBA painting remains intact inside each extracted part.

Native source reload passed and final joint metadata re-bake preserved all reviewed body/effect hashes. Evidence in `build/verification/phase3/08-parallel/map_a/`: sentinel body visual contact, native combined contact, original/quarter body WebP, `sentinel-browser-effects.jpg`, technical candidate and isolated native logs. Each four-frame body/effect set has 1,048,576 decoded RGBA bytes, 2 MiB combined resource data; this is not measured runtime cache/device performance. Combined preview PNGs are review-only.

`sentinel_publish_review.json` explicitly binds the reviewed body and independently disableable effect hashes. `sentinel_map_review.html` supports playback/step/frame selection and effect checkbox. Production integration and final human naturalness/art review remain with coordinator/user.
