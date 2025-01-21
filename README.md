# Listen

_**Heavily**_ influenced by [`hear`][1] by Sveinbjorn Thordarson, but written in Swift, using ArgumentParser and packaged by SPM.

## Example usage

Transcribe audio from the microphone, on-device (`-d`), over-writing a single line ('-m'), inserting punctuation (`-p`) and exiting when a phrase ends with the word "exit" (`-x exit`).

    listen -d -m -p -x exit
   
List available languages

    listen -s
    
Transcribe the contents of an audio file (`-i filename`), writing output to a file (`> outname`).

    listen -i "some audio file.mp3" > "some transcription.txt"

Print usage instructions

    listen -h

 [1]: https://github.com/sveinbjornt/hear.git

