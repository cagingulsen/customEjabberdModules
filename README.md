# Custom eJabberd Modules

----

I used Filtering (mod\_filterlatlong) and Broadcasting(mod\_broadcastlatlong) modules for handling real-time location data of the transportation units in one of my projects.

1) mod\_filterlatlong filters messages by their message body. It checks if the body of the message starts with the predefined string. If it is positive, then it extracts latitude, longitude and id number values. Finally, the module updates corresponding rows in MySQL table using these obtained values.

2) mod\_broadcastlatlong again filters messages by their message body. If the body starts with the predefined string, it fetches data from MySQL database and broadcasts in the chat every 20 seconds.

eJabberd Server Version: 16.02 Linux 

----

## How to use modules?

For detailed eJabberd module information, please visit: [https://docs.ejabberd.im/developer/extending-ejabberd/modules/](https://docs.ejabberd.im/developer/extending-ejabberd/modules/)

For summary:

### Install a custom module

For mod\_filterlatlong:

Move the custom module folder to the path:
> $HOME/.ejabberd-modules/sources/mod\_filterlatlong

Then install the module:
> $ ejabberdctl module\_install mod\_filterlatlong

Check your new module is installed:
> $ ejabberdctl modules\_installed

The response should contain:

> mod\_filterlatlong

You can remove the module by using:
> ejabberdctl module\_uninstall mod\_filterlatlong

After installation, you’ll need to restart ejabberd or manually start the module.