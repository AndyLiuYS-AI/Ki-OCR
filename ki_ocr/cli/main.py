# Modified for Ki-OCR (2026-11-15); derived from the SoMark upstream project.
import typer
from ki_ocr.cli.cmd_serve import serve

app = typer.Typer(help="Ki-OCR: document parsing")


@app.callback()
def main():
    # Keep the explicit `serve` subcommand when it is the only command.
    pass


app.command(name="serve", help="Start the KiOCR server with its Online Demo at /demo")(serve)

if __name__ == "__main__":
    app()
