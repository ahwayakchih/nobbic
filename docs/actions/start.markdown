Usage
=====

## `build` APP_NAME
## `start` APP_NAME

The only difference between `build` and `start` is that `start` will automatically `build` if specified forum was not built yet and then it will start pod and containers (`build` does not start anything).

Both support various options passed through environment variables. You can either set them up beforehand or use one liners,
like it was shown in a [README.markdown](../README.markdown):

```sh
APP_USE_FQDN=localhost APP_ADD_REDIS=1 nobbic start my-new-forum
```

This will create and start pod named "my-new-forum", that will use latest Redis database and serve NodeBB at http://localhost:8080.

For a full list of available options, read [BuildAndStart.markdown](./BuildAndStart.markdown).
