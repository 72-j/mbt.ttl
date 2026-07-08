///|
fn main {
  // @backtrace.initialize()
  cmd_parser()
}

///|
pub fn cmd_parser() -> Unit {
  let cmd = @argparse.Command(
    "demo",
    flags=[
      FlagArg("verbose", short='v', long="verbose"),
      FlagArg("test", short='t', long="test"),
    ],
    options=[
      OptionArg("count", long="count", env="COUNT"),
      OptionArg("name", long="name", env="NAME"),
    ],
    positionals=[PositionArg("name2"), PositionArg("name3")],
  )
  let cmd = try cmd.parse() |> Ok catch {
    e => Err(e)
  }
  match cmd {
    Ok(cmd) => {
      println("cmd: \{@debug.to_string(cmd.flags)}")
      println("flags: \{@debug.to_string(cmd.values)}")
      println("sources: \{@debug.to_string(cmd.sources)}")
    }
    Err(e) => println("error: \{e}")
  }
}
