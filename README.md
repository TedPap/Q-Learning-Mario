# Q-Learning-Mario
Playing Super Mario World with Q-Learing

## Getting Started

Follow the steps in "Installation" and "Running the Project" to begin.

### Installation

Download or clone the repository to your machine.

Install /Dependencies/bizhawk_prereqs.exe or download and install https://github.com/TASVideos/BizHawk-Prereqs/releases/tag/2.1

### Running the Project

Open BizHawk folder

Run EmuHawk.exe

In the emulator press File -> Open ROM and choose /Dependencies/Super Mario World (USA).smc . The game should now load in the emulator

In the emulator press Tools -> Lua Console

In the Lua Console press Script -> Open Script and then choose /Dependencies/BIZHAWK/Lua/Q-Learning_Super_Mario_World.lua

Mario should now begin to play on his own!

## Built With

* [Lua](https://www.lua.org/) - The programming language used
* [Maven](http://tasvideos.org/BizHawk.html) - The emulator used to run the agent

## Authors

* **Ted Pap** - *Initial work* - [PurpleBooth](https://github.com/TedPap)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Acknowledgments

* Many thanks to Seth Bling for his awesome open-source project MarI/O at https://www.youtube.com/watch?v=qv6UVOQ0F44. Without his work on the BizHawk API this project whould not be possible.
