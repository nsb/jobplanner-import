defmodule JobplannerImport.CLI do
  def main(args) do
    parse_args(args)
    |> process
  end

  def parse_args(args) do
    parse = OptionParser.parse(args, switches: [help: :boolean], aliases: [h: :help])

    case parse do
      {[help: true], _, _} ->
        :help

      {_, [csv_file], _} ->
        csv_file
    end
  end

  def process(:help) do
    IO.puts("""
    Jobplanner import
    """)
  end

  def process(csv_file) do
    JobplannerImport.run(csv_file)
  end
end
