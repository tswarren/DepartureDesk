_departure_desk_exec() { ./dev/rails-docker "$@"; }

rails()     { _departure_desk_exec bin/rails "$@"; }
rake()      { _departure_desk_exec bin/rake "$@"; }
ruby()      { _departure_desk_exec ruby "$@"; }
bundle()    { _departure_desk_exec bundle "$@"; }
rubocop()   { _departure_desk_exec bundle exec rubocop "$@"; }
brakeman()  { _departure_desk_exec bundle exec brakeman "$@"; }
console()   { _departure_desk_exec bin/rails console "$@"; }
dbconsole() { _departure_desk_exec bin/rails dbconsole "$@"; }