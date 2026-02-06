const path    = require("path")
const webpack = require("webpack")

module.exports = {
  mode: "production",
  devtool: "source-map",
  entry: {
    application: "./app/javascript/application.js",
    ui_components: "./app/javascript/packs/ui_components.js",
    legacy: "./app/javascript/packs/legacy.js"
  },
  output: {
    filename: "[name].js",
    sourceMapFilename: "[file].map",
    chunkFormat: "module",
    path: path.resolve(__dirname, "app/assets/builds"),
  },
  module: {
    rules: [
      {
        test: /\.erb$/,
        enforce: 'pre',
        loader: 'rails-erb-loader',
        options: {
          runner: (/^win/.test(process.platform) ? 'ruby ' : '') + 'bin/rails runner'
        }
      }
    ]
  },
  plugins: [
    new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 1
    }),
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery',
      Popper: ['popper.js', 'default']
    })
  ]
}
