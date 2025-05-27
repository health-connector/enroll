const { webpackConfig, merge } = require('@rails/webpacker')

const options = {
    resolve: {
        extensions: [
            '.js',
            '.sass',
            '.scss',
            '.css',
            '.module.sass',
            '.module.scss',
            '.module.css',
            '.png',
            '.svg',
            '.gif',
            '.jpeg',
            '.jpg'
        ]
    }
}

module.exports = merge(webpackConfig, options)
