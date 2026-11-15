#!/bin/sh
# Renders the phrases (tools/voice.js lines, the SNES port's list) with Windows
# SAPI (Microsoft David, as on the Tandy and SNES) at 22 kHz 16-bit mono into
# build/speech/. Needs Windows: run from Git Bash.
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/speech
node tools/voice.js --lines > build/speech/lines.txt || exit 1
powershell.exe -NoProfile -Command "
\$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
\$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$s.SelectVoice('Microsoft David Desktop')
\$s.Rate = 0
Get-Content 'build/speech/lines.txt' | ForEach-Object {
  \$p = \$_.Split('|')
  \$out = Join-Path (Get-Location) ('build/speech/' + \$p[0] + '.wav')
  \$s.SetOutputToWaveFile(\$out, \$fmt)
  \$s.Speak(\$p[1])
  \$s.SetOutputToNull()
}
\$s.Dispose()
" || exit 1
cp build/speech/lines.txt build/speech/rendered.txt
