# Zinecraft 
A direct port of Minecraft from Java to Zig. This project was completely stopped back when Zig 0.11.0 was the latest version in favor of using C++. I got stuck somewhere while debugging And dropped it.

### Usage
This is intended to have as many Minecraft versions as possible. When building the project, you can choose what Minecraft version you'd like to use like this:
```
zig build -Dversion=<version> -Dconnection=<client|server> -Dfullscreen=<true|false>
```

### AI Disclaimer
While the initial port of all code is hand-written by me, occasionally I will use AI to compare the port with the original and see if I made any mistakes. It's not always very good at it so I try to not rely on it lol.

### Currently Available Versions
rd-132211
rd-132328
rd-160052
rd-161348
c0.0.12-dev (c0.0.11 in launcher) (currently in beta)
