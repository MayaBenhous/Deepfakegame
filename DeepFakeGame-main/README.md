# Face Check

A lightweight, offline-friendly 3×3 exhibition game. Players choose the three real faces from a grid containing three real and six fake faces.

The interface is in Hebrew. Each round lasts 30 seconds, the third face selection submits automatically, and the intro screen can be started with any of the nine controller buttons.

**🎮 [Play the Game Online (GitLab Pages)](https://lichvladimir.gitlab.io/DeepFakeGame)**


## Add your images

1. Copy real face images into `faces/real`.
2. Put fake images into one folder per attack inside `faces/fake`, such as `genai`, `morph`, and `PGD`.
3. Double-click `UPDATE_FACES.bat`.
4. Double-click `index.html` to play.

Use at least 3 real images and at least 2 images in each of 3 attack folders. Every round draws 3 real faces and exactly 2 fake faces from each attack, for 9 faces total. Supported image types are JPG, JPEG, PNG, WebP, GIF, and AVIF. If there are not enough images, the game starts in a clearly marked demo mode.

## Controls

- Mouse or touch: tap three faces. The third choice checks the answer automatically.
- Keyboard/controller: keys `1` through `9` match the physical 3×3 positions. After a win or loss, pressing any of the nine face buttons starts a fresh round. `Enter` also starts the next round; `R` or `Escape` resets.
- Optional serial scaffold: click **Controller ready** or press `C`. A serial controller can send `1`-`9`, `SUBMIT`, or `RESET`, each followed by a newline, at 9600 baud. Web Serial requires Chrome or Edge on `localhost` or HTTPS.
- The simplest Arduino option is a board that can act as a USB keyboard. Have its nine buttons send keys `1`-`9`; this works without serial setup.

The game resets automatically after results or after one minute of inactivity, making it suitable for an unattended project stall.
