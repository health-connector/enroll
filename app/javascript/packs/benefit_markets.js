import "@babel/polyfill";
import { Application } from "@hotwired/stimulus"
import { definitionsFromContext } from "@hotwired/stimulus-webpack-helpers"

const application = Application.start()
const context = require.context("benefit_markets/controllers", true, /.js$/)
application.load(definitionsFromContext(context))
