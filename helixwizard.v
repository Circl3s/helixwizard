module main

import term
import readline
import json
import os
import math as maths

struct Episode {
	pub mut:
		title string
		source string
}

fn (e Episode) print() {
	println(term.bold(e.title))
	println("  └── Source: $e.source")
}

struct Series {
	pub mut:
		title string
		tags []string
		cover string
		bg string
		episodes []Episode
}

fn (s Series) print() {
	println(term.header_left(term.bold(s.title), "-"))
	println("Tags: " + s.tags.join(", "))
	println("Cover image: " + s.cover)
	println("Background image: " + s.bg)
	println("Episodes: " + s.episodes.len.str())
	println(term.h_divider("-"))
}

fn (s Series) print_episodes() {
	for e in s.episodes {
		e.print()
	}
}

struct State {
	pub mut:
		index map[string]Series
		backup map[string]Series
		running bool = true
		active_series_key string
		active_episode_nr int = -1
		unsaved_changes bool
		are_you_sure bool
}

fn (mut s State) set_active_episode(nr int | string) {
	if nr is string {
		s.active_episode_nr = nr.int()
	} else if nr is int {
		s.active_episode_nr = nr
	}
	println(term.ok_message("You're now editing " + s.active_series().title + ", " + s.active_episode().title + "."))
}

fn (mut s State) set_active_series(key string) {
	s.active_series_key = key
	s.active_episode_nr = -1
	println(term.ok_message("You're now editing " + s.active_series().title + "."))
}

fn (s State) active_series() Series {
	return s.index[s.active_series_key]
}

fn (s State) active_episode() Episode {
	return s.index[s.active_series_key].episodes[s.active_episode_nr]
}

fn (s State) print_keys() {
	for key, series in s.index {
		println("$key: ${series.title}")
	}
}

fn (s State) editing_series() bool {
	return s.active_series_key != "" && s.active_episode_nr == -1
}

fn (s State) editing_episode() bool {
	return s.active_series_key != "" && s.active_episode_nr != -1
}

fn (s State) prompt() string {
	mut prompt := term.red("Helix ")
	if s.active_series_key != "" {
		prompt += "> " + s.active_series().title + " "
	}
	if s.active_episode_nr != -1 {
		prompt += "> " + s.active_episode().title + " "
	}
	prompt += if s.unsaved_changes { term.yellow("> ") } else { "> " }
	return term.bold(prompt)
}

fn (mut s State) exit() {
	if s.unsaved_changes && !s.are_you_sure {
		println(term.warn_message('You have unsaved changes! Exit again to ignore.'))
		s.are_you_sure = true
	} else {
		s.running = false
	}
}

fn (mut s State) parse(command string) {
	args := command.trim_space().split(" ")
	match args[0] {
		"exit", "cancel" {
			s.exit()
		}
		"dump" {
			println(s.index)
		}
		"series", "s" {
			if args.len > 1 {
				if args[1] in s.index {
					s.set_active_series(args[1])
				} else {
					println(term.fail_message("You have to specify a valid key."))
				}
			} else {
				s.print_keys()
			}
		}
		"episode", "ep", "entry", "episodes" {
			if s.editing_series() || s.editing_episode() {
				if args.len > 1 {
					s.set_active_episode(maths.min<int>(maths.max<int>(args[1].int() - 1, 0), s.active_series().episodes.len - 1))
				} else {
					s.active_series().print_episodes()
				}
			} else {
				println(term.fail_message("You need to be editing a series to do that."))
			}
		}
		"done", "back", "up" {
			if s.editing_episode() {
				s.active_episode_nr = -1
			} else if s.editing_series() {
				s.active_series_key = ""
			} else {
				s.exit()
			}
		}
		"info", "i", "details" {
			if s.editing_series() {
				s.active_series().print()
			} else if s.editing_episode() {
				s.active_episode().print()
			} else {
				println(term.fail_message("You need to be editing a series or episode to do that."))
			}
		}
		"title", "t" {
			if s.editing_series() {
				if args.len > 1 {
					mut edit := s.active_series()
					edit.title = args[1..].join(" ")
					s.index[s.active_series_key] = edit
					s.unsaved_changes = true
				} else {
					println(s.active_series().title)
				}
			} else if s.editing_episode() {
				if args.len > 1 {
					mut edit := s.active_series()
					edit.episodes[s.active_episode_nr].title = args[1..].join(" ")
					s.index[s.active_series_key] = edit
					s.unsaved_changes = true
				} else {
					println(s.active_episode().title)
				}
			} else {
				println(term.fail_message("You need to be editing a series or episode to do that."))
			}
		}
		"source", "src" {
			if s.editing_episode() {
				if args.len > 1 {
					mut edit := s.active_series()
					edit.episodes[s.active_episode_nr].source = args[1]
					s.index[s.active_series_key] = edit
					s.unsaved_changes = true
				} else {
					println(s.active_episode().source)
				}
			} else {
				println(term.fail_message("You need to be editing an episode to do that."))
			}
		}
		"tags" {
			if s.editing_series() {
				if args.len > 1 {
					mut edit := s.active_series()
					match args[1] {
						"+" {
							if args.len > 2 {
								edit.tags << args[2..]
							} else {
								println(term.fail_message("You need to specify tags to add."))
							}
						}
						"-" {
							if args.len > 2 {
								edit.tags = edit.tags.filter(it !in args[2..])
							} else {
								println(term.fail_message("You need to specify tags to remove."))
							}
						}
						"clear" {
							edit.tags.clear()
						}
						else {
							edit.tags = args[1..]
						}
					}
					s.index[s.active_series_key] = edit
					s.unsaved_changes = true
				} else {
					println(s.active_series().tags.join(", "))
				}
			} else {
				println(term.fail_message("You need to be editing a series to do that."))
			}
		}
		"cover" {
			if s.editing_series() {
				if args.len > 1 {
					mut edit := s.active_series()
					edit.cover = args[1]
					s.index[s.active_series_key] = edit
					s.unsaved_changes = true
				} else {
					println(s.active_series().cover)
				}
			} else {
				println(term.fail_message("You need to be editing a series to do that."))
			}
		}
		"background", "bg" {
			if s.editing_series() {
				if args.len > 1 {
					mut edit := s.active_series()
					edit.bg = args[1]
					s.index[s.active_series_key] = edit
					s.unsaved_changes = true
				} else {
					println(s.active_series().bg)
				}
			} else {
				println(term.fail_message("You need to be editing a series to do that."))
			}
		}
		"key" {
			if s.editing_series() {
				if args.len > 1 {
					if args[1] !in s.index {
						mut edit := s.active_series()
						s.index.delete(s.active_series_key)
						s.active_series_key = args[1]
						s.index[s.active_series_key] = edit
						s.unsaved_changes = true
						println(term.warn_message("Warning: Helix by default presumes that each series' assets are in a directory of the same name as its key; make sure the paths are correct or rename directories accordingly."))
					} else {
						println(term.fail_message("There's already a series using that key."))
					}
				} else {
					println(s.active_series_key)
				}
			} else {
				println(term.fail_message("You need to be editing a series to do that."))
			}
		}
		"new", "add", "create" {
			if args.len > 1 {
				match args[1] {
					"series", "s" {
						if args.len > 2 {
							if args[2] !in s.index {
								mut edit := Series{title: args[2]}
								s.index[args[2]] = edit
								s.set_active_series(args[2])
								s.unsaved_changes = true
							}
						} else {
							println(term.fail_message("You need to specify a unique key for the series."))
						}
					}
					"episode", "ep", "entry" {
						if s.editing_series() || s.editing_episode() {
							mut edit := s.active_series()
							new_index := edit.episodes.len + 1
							edit.episodes << Episode{title: "Episode $new_index"}
							s.index[s.active_series_key] = edit
							s.set_active_episode(new_index - 1)
							s.unsaved_changes = true
						} else {
							println(term.fail_message("You need to be editing a series to do that."))
						}
					}
					else {
						println(term.fail_message("You can only create series and episodes."))
					}
				}
			} else {
				println(term.fail_message("You need to specify what to create."))
			}
		}
		"delete" {
			if s.editing_series() {
				title := s.active_series().title
				s.index.delete(s.active_series_key)
				s.active_series_key = ""
				println(term.warn_message(term.bold("You have deleted ${title}. ") + "Once you save there will be no going back."))
				s.unsaved_changes = true
			} else if s.editing_episode() {
				mut edit := s.active_series()
				title := s.active_episode().title
				edit.episodes.delete(s.active_episode_nr)
				s.active_episode_nr = -1
				s.index[s.active_series_key] = edit
				println(term.warn_message(term.bold("You have deleted ${title}. ") + "Once you save there will be no going back."))
				s.unsaved_changes = true
			} else {
				println(term.fail_message("You need to be editing a series or episode to do that."))
			}
		}
		"save" {
			data := json.encode(s.index)
			os.write_file("index.json", data) or {
				println(term.fail_message('Couldn\'t write to "index.json".'))
				return
			}
			s.unsaved_changes = false
			s.are_you_sure = false
		}
		"help", "wtf", "?" {
			println(term.header_left(term.bold("List of available commands"), "-"))
			//
			println(term.bold("exit"))
			println(term.bold("  ├── Description: ") + "Exits the wizard. Will warn you if you have any unsaved changes.")
			println(term.bold("  ├── Executable in: ") + term.green("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			println(term.bold("  ├── Aliases: ") + "cancel")
			println(term.bold("  └── Note: ") + "You can also exit by repeatedly typing ${term.bold("back")} or by pressing Ctrl+C (though that won't give you a warning).")
			//
			println(term.bold("series <key>"))
			println(term.bold("  ├── Description: ") + "Changes the series you're editing. When not supplied with a series key, it prints out all available series with their keys.")
			println(term.bold("  ├── Executable in: ") + term.green("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			println(term.bold("  ├── Aliases: ") + "s")
			println(term.bold("  └── Note: ") + "When not editing anything, you can just type in the series key to start editing.")
			//
			println(term.bold("episode <nr>"))
			println(term.bold("  ├── Description: ") + "Changes the episode you're editing. When not supplied with a number, it prints out all available episodes in the current series.")
			println(term.bold("  ├── Executable in: ") + term.red("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			println(term.bold("  └── Aliases: ") + "ep entry episodes")
			//
			println(term.bold("title <title>"))
			println(term.bold("  ├── Description: ") + "Changes the title of the series or episode you're editing. When not supplied with a title, it prints out the current title.")
			println(term.bold("  ├── Executable in: ") + term.red("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			println(term.bold("  └── Aliases: ") + "t")
			//
			println(term.bold("tags <+/-/clear> <tags>"))
			println(term.bold("  ├── Description: ") + "Changes the tags of the series you're editing. When not supplied with any tags, it prints out the current tags.")
			println(term.bold("  ├── Executable in: ") + term.red("ROOT ") + term.green("SERIES ") + term.red("EPISODE"))
			println(term.bold("  └── Note: ") + '"+" adds the tags to the current ones, "-" removes the tags, "clear" removes ${term.bold("all")} the tags, and if not supplied with any of those, it overwrites the current tags.')
			//
			println(term.bold("cover <path>"))
			println(term.bold("  ├── Description: ") + "Changes the cover of the series you're editing. When not supplied with a path, it prints out the current cover path.")
			println(term.bold("  ├── Executable in: ") + term.red("ROOT ") + term.green("SERIES ") + term.red("EPISODE"))
			println(term.bold("  └── Note: ") + "If left blank, Helix will look for the cover in ${term.italic("./content/<key>/cover.jpg")}.")
			//
			println(term.bold("background <path>"))
			println(term.bold("  ├── Description: ") + "Changes the background of the series you're editing. When not supplied with a path, it prints out the current background path.")
			println(term.bold("  ├── Executable in: ") + term.red("ROOT ") + term.green("SERIES ") + term.red("EPISODE"))
			println(term.bold("  ├── Aliases: ") + "bg")
			println(term.bold("  └── Note: ") + "If left blank, Helix will look for the background in ${term.italic("./content/<key>/bg.jpg")}.")
			//
			println(term.bold("key <new key>"))
			println(term.bold("  ├── Description: ") + "Changes the unique key of the series you're editing. When not supplied with a key, it prints out the current key.")
			println(term.bold("  ├── Executable in: ") + term.red("ROOT ") + term.green("SERIES ") + term.red("EPISODE"))
			println(term.bold("  └── Note: ") + "When changing, note the default paths, like stated above.")
			//
			println(term.bold("source <path>"))
			println(term.bold("  ├── Description: ") + "Changes the video path of the episode you're editing. When not supplied with a path, it prints out the current video path.")
			println(term.bold("  ├── Executable in: ") + term.red("ROOT ") + term.red("SERIES ") + term.green("EPISODE"))
			println(term.bold("  ├── Aliases: ") + "src")
			println(term.bold("  └── Note: ") + "Due to browser limitations, Helix only accepts web-friendly formats like ${term.bold(".mp4")} or ${term.bold(".webm")}. Ffmpeg is your friend.")
			//
			println(term.bold("save"))
			println(term.bold("  ├── Description: ") + "Saves pending changes to disk.")
			println(term.bold("  ├── Executable in: ") + term.green("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			println(term.bold("  └── Note: ") + "There's no auto-saving, remember to save often! The prompt will be yellow if there are any unsaved changes.")
			//
			println(term.bold("info"))
			println(term.bold("  ├── Description: ") + "Prints out info about the current episode or series.")
			println(term.bold("  ├── Executable in: ") + term.green("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			println(term.bold("  └── Aliases: ") + "i details")
			//
			println(term.bold("dump"))
			println(term.bold("  ├── Description: ") + "Prints out ${term.bold("all")} the info stored in the index file. Mostly for debugging.")
			println(term.bold("  └──Executable in: ") + term.green("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			//
			println(term.bold("back"))
			println(term.bold("  ├── Description: ") + "Backs out, ie. if editing an episode, it will go back to editing the series, and if ran from the root it will exit the wizard.")
			println(term.bold("  ├── Executable in: ") + term.green("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			println(term.bold("  └── Aliases: ") + "done up")
			//
			println(term.bold("new [series/episode] <key>"))
			println(term.bold("  ├── Description: ") + "Creates a new series or episode. If creating a new series, you have to specify a unique key.")
			println(term.bold("  ├── Executable in: ") + term.yellow("ROOT ") + term.green("SERIES ") + term.green("EPISODE") + term.yellow(" (Only series in root.)"))
			println(term.bold("  ├── Aliases: ") + "add create")
			println(term.bold("  └── Note: ") + 'You can also use shorter versions of "series" and "episode": ${term.bold("s")} and ${term.bold("ep")}.')
			//
			println(term.bold("delete"))
			println(term.bold("  ├── Description: ") + "Deletes the ${term.bold("current")} series or episode.")
			println(term.bold("  ├── Executable in: ") + term.red("ROOT ") + term.green("SERIES ") + term.green("EPISODE"))
			println(term.bold("  └── Note: ") + "The deletion won't take effect until you ${term.bold("save")}. If you've made a mistake just exit and try again.")
		}
		else {
			if args[0] in s.index {
				s.set_active_series(args[0])
			} else {
				println(term.fail_message('Unknown command. Type "help" to see available commands.'))
			}
		}
	}
}

fn main() {
	term.set_terminal_title("Helix Wizard")
	i := os.read_file("./index.json") or {
		"{}"
	}
	index := json.decode(map[string]Series, i)?
	mut s := State{
		index: index
	}
	mut r := readline.Readline{}
	println('Welcome to the Helix Wizard.')
	for s.running {
		answer := r.read_line(s.prompt()) or { "" }
		s.parse(answer)
	}
}
