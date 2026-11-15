#!/bin/sh
# Renders the phrases in tandy1000/yacht/tools/speech.txt with Windows SAPI (Microsoft
# David, as on the Tandy) at 22 kHz 16-bit mono into build/speech/.
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/speech
powershell.exe -NoProfile -Command "
Add-Type -AssemblyName System.Speech
\$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$s.SelectVoice('Microsoft David Desktop')
\$s.Rate = 0
Get-Content '../../tandy1000/yacht/tools/speech.txt' | ForEach-Object {
  \$p = \$_.Split('|')
  \$out = Join-Path (Get-Location) ('build/speech/' + \$p[0] + '.wav')
  \$s.SetOutputToWaveFile(\$out, \$fmt)
  \$s.Speak(\$p[1])
  \$s.SetOutputToNull()
}
\$s.Dispose()
"
