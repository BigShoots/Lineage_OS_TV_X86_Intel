# Multipart Release Asset Notes

GitHub release assets must be smaller than 2 GiB each. Split the ISO into 1900 MiB 7z volumes before uploading:

```bash
7z a -t7z -mx=0 -v1900m lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output-gapps.iso.7z \
  lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output-gapps.iso
```

This produces files like:

- `lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output-gapps.iso.7z.001`
- `lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output-gapps.iso.7z.002`

To extract:

```bash
7z x lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output-gapps.iso.7z.001
```
