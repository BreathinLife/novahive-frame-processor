# =============================================
# Video-Agent Frame Processor for Windows
# Handles 462+ frame sequences (intimate scenes)
# =============================================

$INPUT_DIR = "raw_frames"
$OUTPUT_DIR = "processed"
$TOPIC = "intimate-oral"
$VIGNETTE_ID = "v015"
$SCENE_NUM = "012"
$CLIP_TYPE = "main-closeup"
$FPS = 30
$TARGET_DURATION = 15   # Change this as needed

Write-Host "=== Video-Agent Frame Processor (Windows) ===" -ForegroundColor Cyan

# Create directories
New-Item -ItemType Directory -Force -Path "$OUTPUT_DIR\$TOPIC\vignettes\$VIGNETTE_ID\raw_frames" | Out-Null
New-Item -ItemType Directory -Force -Path "$OUTPUT_DIR\$TOPIC\vignettes\$VIGNETTE_ID\keyframes" | Out-Null
New-Item -ItemType Directory -Force -Path "$OUTPUT_DIR\$TOPIC\vignettes\$VIGNETTE_ID\clips" | Out-Null

Write-Host "Processing $INPUT_DIR ..." -ForegroundColor Yellow

# 1. Copy frames if raw_frames folder exists
if (Test-Path $INPUT_DIR) {
    Copy-Item "$INPUT_DIR\*" "$OUTPUT_DIR\$TOPIC\vignettes\$VIGNETTE_ID\raw_frames\" -ErrorAction SilentlyContinue
    Write-Host "✓ Frames copied" -ForegroundColor Green
} else {
    Write-Host "Warning: $INPUT_DIR folder not found. Create it and put your frames inside." -ForegroundColor Red
}

# 2. Extract Keyframes (every 25 frames)
Write-Host "Extracting keyframes..." -ForegroundColor Yellow
for ($i = 1; $i -le 462; $i += 25) {
    $padded = "{0:D4}" -f $i
    $source = "$OUTPUT_DIR\$TOPIC\vignettes\$VIGNETTE_ID\raw_frames\frame_${padded}.jpg"
    if (Test-Path $source) {
        Copy-Item $source "$OUTPUT_DIR\$TOPIC\vignettes\$VIGNETTE_ID\keyframes\keyframe_${padded}.jpg"
    }
}
Write-Host "✓ Keyframes extracted" -ForegroundColor Green

# 3. Generate Video Clip using FFmpeg
Write-Host "Generating video clip..." -ForegroundColor Yellow

$inputPattern = "$OUTPUT_DIR\$TOPIC\vignettes\$VIGNETTE_ID\raw_frames\frame_%04d.jpg"
$outputFile = "$OUTPUT_DIR\$TOPIC\vignettes\$VIGNETTE_ID\clips\${VIGNETTE_ID}_${TOPIC}_${SCENE_NUM}_${CLIP_TYPE}_${TARGET_DURATION}s_v1.mp4"

ffmpeg -framerate $FPS -start_number 1 `
       -i $inputPattern `
       -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2" `
       -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p `
       -t $TARGET_DURATION `
       $outputFile

Write-Host "✓ Main clip created: $outputFile" -ForegroundColor Green
Write-Host "`nDone! Check the 'processed' folder." -ForegroundColor Cyan