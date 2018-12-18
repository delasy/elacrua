# Elacrua
IKEv2 VPN server set up script for Ubuntu Server 18.04


## Table of Contents

1. [Description](#description)
2. [Installation](#installation)
3. [Working with users](#working-with-users)
4. [Usefull links](#usefull-links)
5. [The Author](#the-author)
6. [License](#license)


## Description

Sorry for so "thick" description for this script. I don't have enough time to write more detailed description. \
If you have any question, please create issue i will respond you as fast as i can. \
Also you can support me by giving a star for this repository. It would motivate me for improvements. \
I was inspired by [this](https://github.com/jawj/IKEv2-setup) script.
But when i was installing it i got in trouble, VPN wasn't setted up as expected. So i had to write my own. \
It was a short story how i was involved to write it. So i hope it will help anyone. \
Also i want to say sorry for my russian-english, i don't have enough knowledge to write this README without mystakes. \
PRs to improve spelling are accepted!
Also, thank you for reading!


## Installation

```bash
wget https://raw.githubusercontent.com/delasy/elacrua/master/configure.sh
chmod a+x configure.sh
sudo ./configure.sh
```

After that your server wil be restarted. It become available in less than one minute. And you can start using your VPN.


## Working with users

To add or change users credentials edit file `/etc/ipsec.secrets`.

> NOTE: System requires root privileges to edit this file.

You can do it like so:

```bash
sudo vim /etc/ipsec.secrets
```

> NOTE: First line specifies the server certificate, please don't delete it or modify.

After first line goes user's credentials, in the following format: `username : EAP "userpass"`. \
After editing `/etc/ipsec.secrets` file don't forget to load new users credentials into ipsec.

> NOTE: System also requires root privileges to execute this command.

You can do it like so:

```bash
sudo ipsec secrets
```


## Usefull links

1. [Set Up an IKEv2 VPN Server with StrongSwan on Ubuntu 18.04](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ikev2-vpn-server-with-strongswan-on-ubuntu-18-04-2)
2. [Secure Nginx with Let's Encrypt on Ubuntu 18.04](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-18-04)


## The Author

This script was written by [Aaron Delasy](https://github.com/delasy) in 2018. \
<aaron@delasy.com>


## License

This script is distributed under the terms of Apache License (Version 2.0). \
See [LICENSE.md](LICENSE.md) for details.
