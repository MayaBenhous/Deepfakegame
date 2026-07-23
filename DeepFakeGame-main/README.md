# Face Check

A lightweight, offline-friendly 3×3 exhibition game. Players choose the three real faces from a grid containing three real and six fake faces.

The interface is in Hebrew. Each round lasts 30 seconds, the third face selection submits automatically, and the intro screen can be started with any of the nine controller buttons.

**🎮 [Play the Game Online (GitLab Pages)](https://lichvladimir.gitlab.io/DeepFakeGame)**

## Run on a Windows exhibition PC

1. Copy the entire `DeepFakeGame-main` folder to the PC.
2. Connect the Arduino by USB.
3. Make sure Python and the Arduino Serial Monitor are closed.
4. Double-click `START_GAME.bat`.
5. Keep the launcher window open while the game is running.

The launcher uses Windows PowerShell, detects the USB serial device, opens it at 9600 baud, starts a local server, and opens Chrome (or Edge as a fallback). It does not require Python, browser USB permission, or downloaded packages. For a hosted deployment, upload the folder contents to any HTTPS static host; the launcher files are ignored by the website and the browser's Web Serial support is used as a fallback.


## Add your images

1. Copy real face images into `faces/real`.
2. Put fake images into one folder per attack inside `faces/fake`, such as `genai`, `morph`, and `PGD`.
3. Double-click `UPDATE_FACES.bat`.
4. Double-click `index.html` to play.

Use at least 3 real images and at least 2 images in each of 3 attack folders. Every round draws 3 real faces and exactly 2 fake faces from each attack, for 9 faces total. Supported image types are JPG, JPEG, PNG, WebP, GIF, and AVIF. If there are not enough images, the game starts in a clearly marked demo mode.

## Controls

- Mouse or touch: tap three faces. The third choice checks the answer automatically.
- Keyboard/controller: keys `1` through `9` match the physical 3×3 positions. After a win or loss, pressing any of the nine face buttons starts a fresh round. `Enter` also starts the next round; `R` or `Escape` resets.
- Arduino serial controller on Windows: close Python and the Arduino Serial Monitor, then start the game with `START_GAME.bat`. The launcher detects and opens the USB COM port automatically. No controller controls or USB chooser are shown in the public game UI.
- The controller sends `1`-`9` followed by a newline at 9600 baud. The game sends `Y` after a valid button press, then `G` or `R` one second after the third selection.
- The USB port can have a different `COM` number on another PC; the browser's port chooser handles this automatically.
- A USB-keyboard Arduino can still send keys `1`-`9` without using the serial connection, but the game window must have focus and it will not receive the `Y`, `G`, or `R` light commands.

The game resets automatically after results or after one minute of inactivity, making it suitable for an unattended project stall.
