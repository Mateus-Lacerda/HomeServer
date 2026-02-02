# Home Server

This is a project made for me. To make my life easier.
The goal is to make local development easier when the code is running on a server.
We achieve this by making an interface whose goal it to solely generate a command like this:

```bash
ssh -L <local-port>:localhost:<remote-port> user-name@server-host
```

But I wanted it to be easier to configure and also make it pretier.


## Features:
- Create custom remote server configuration.
- For each server configured, make templates based on the ports you need to forward to your local machine.
- Auto discover services' ports with Docker.
- Add custom services.

...
- Glass


## Future features
- Easy way to make repositories on the server sync with the local environment.
- Make templates editable and removable.
- Run how many templates I want in parallel.
- Support custom host names.
- Menu bar menu to hide the dock icon as the Lord intended.
- Pretty icon.


Vibe coded with no shame.
