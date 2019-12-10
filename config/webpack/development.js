process.env.NODE_ENV = process.env.NODE_ENV || 'development'

const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const environment = require('./environment');
const webpack_environment = environment.toWebpackConfig();

module.exports = webpack_environment;
