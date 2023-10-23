# dev container instructions

The configuration of the .devcontainer is towards M1 mac that are unable to compile some of the native gem requirements.

The high level instructions will be:

1. click on the bottom left corner of the vscode window where it says `><` and select `Remote-Containers: Reopen in Container`
2. wait for the container to build
3. run `bundle install` in the terminal
4. run `npm install` in the terminal
5. run `bin/webpack` in the terminal
6. get a dump of the database from your coworkers
7. run `rails s` in the terminal, the app should be available at `localhost:3001`

`rspec` and `cucumber` command should work.

Note: there are 2 files that are "hacked" to make it work on M1 macs, they are: mogoid.yml and env.rb from cucumber.