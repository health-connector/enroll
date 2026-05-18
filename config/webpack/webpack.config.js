const { generateWebpackConfig } = require('shakapacker')

const customConfig = {
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

module.exports = generateWebpackConfig(customConfig)