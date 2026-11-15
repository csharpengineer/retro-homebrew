#!/bin/sh
# Renders the phrases in speech.txt to 8 kHz, 8-bit mono WAVs with Windows SAPI.
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/speech
powershell.exe -NoProfile -Command "
Add-Type -AssemblyName System.Speech
\$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(8000, [System.Speech.AudioFormat.AudioBitsPerSample]::Eight, [System.Speech.AudioFormat.AudioChannel]::Mono)
\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$s.SelectVoice('Microsoft David Desktop')
\$s.Rate = 0
Get-Content 'tools/speech.txt' | ForEach-Object {
  \$p = \$_.Split('|')
  \$out = Join-Path (Get-Location) ('build/speech/' + \$p[0] + '.wav')
  \$s.SetOutputToWaveFile(\$out, \$fmt)
  \$s.Speak(\$p[1])
  \$s.SetOutputToNull()
}
\$s.Dispose()
"
