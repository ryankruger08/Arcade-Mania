# Arcade Mania

Arcade Mania is a game im working on in Godot where you work at the cafe next door to save up and buy your own arcade. You start with Pong and can buy more machines as you earn money, move them around and open the arcade for customers. You can also just play the machines yourself!

There are currently 7 games:

- Pong
- Space Invaders
- Snake
- Breakout
- Asteroids
- Frogger
- Road Racer

The cafe has customers who come up and order coffee and toast, then sit down for a bit before leaving. Once you own the arcade, customers can come in and pay to use the machines too. There is a sign outside to open and close it and a terminal inside for buying and moving cabinets.

I have also added controller support, changeable controls, sounds and graphics settings from potato to high. Your money, machines, layout and progress save, along with settings and high scores.

## How it works

Each arcade machine runs its game inside a SubViewport which is displayed on the screen of the 3D cabinet. They use the same machine manager script to handle inserting money, starting a game and returning to walking around. This makes it easier to add another game without writing all of that again.

The cafe and arcade customers follow points placed in the map, with different states for walking, waiting, eating or playing. The wallet handles money and purchases, and progress is saved locally using Godot config files. The furniture, signs and customer points are actual nodes in the map so they can be moved around in the editor.

## Controls

WASD to walk, mouse to look, space to jump, E to interact or insert money and F to play or leave a machine. Escape opens the pause menu.

On controller its left stick to walk, right stick to look, A to jump, X to interact or play, right trigger to insert money and Start to pause. You can change the bindings in settings.

## Running it

Open `project.godot` in Godot 4.7.2, let everything import and press F5. You will need Blender installed for the .blend models to import properly.

You can also run it from the itch.io page i have linked in stardance!

Its still being worked on so expect bugs and things to change. I want to add more stuff to do with owning the arcade and hopefully release it on Steam after more work. Please leave suggestions or report any issues here :)
