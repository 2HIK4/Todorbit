using System.IO.Pipes;
using System.Text;

internal sealed class WidgetCommandServer : IDisposable {
  internal const string PipeName = "LifeManager.NativeWidget.Commands.v1";
  private readonly CancellationTokenSource cancellation = new();
  private readonly SynchronizationContext uiContext;
  private readonly Action<string> dispatch;
  private readonly string pipeName;
  private readonly Task listener;

  internal WidgetCommandServer(Action<string> dispatch, string? pipeName = null) {
    this.dispatch = dispatch;
    this.pipeName = pipeName ?? PipeName;
    uiContext = SynchronizationContext.Current ??
      throw new InvalidOperationException("The widget command server requires a UI context.");
    listener = Task.Run(ListenAsync);
  }

  internal static bool TrySend(string command, int timeoutMilliseconds = 5000,
      string? pipeName = null) {
    try {
      using var client = new NamedPipeClientStream(".", pipeName ?? PipeName,
        PipeDirection.Out, PipeOptions.Asynchronous);
      client.Connect(timeoutMilliseconds);
      using var writer = new StreamWriter(client, new UTF8Encoding(false)) {
        AutoFlush = true,
      };
      writer.WriteLine(command);
      return true;
    } catch (TimeoutException) {
      return false;
    } catch (IOException) {
      return false;
    }
  }

  private async Task ListenAsync() {
    while (!cancellation.IsCancellationRequested) {
      try {
        await using var server = new NamedPipeServerStream(pipeName,
          PipeDirection.In, 1, PipeTransmissionMode.Byte,
          PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
        await server.WaitForConnectionAsync(cancellation.Token);
        using var reader = new StreamReader(server, Encoding.UTF8,
          detectEncodingFromByteOrderMarks: true, leaveOpen: true);
        var command = await reader.ReadLineAsync(cancellation.Token);
        if (!string.IsNullOrWhiteSpace(command)) {
          uiContext.Post(_ => dispatch(command.Trim()), null);
        }
      } catch (OperationCanceledException) when (cancellation.IsCancellationRequested) {
        break;
      } catch (IOException) when (!cancellation.IsCancellationRequested) {
        await Task.Delay(100, cancellation.Token);
      }
    }
  }

  public void Dispose() {
    cancellation.Cancel();
    try { listener.Wait(TimeSpan.FromSeconds(2)); } catch { }
    cancellation.Dispose();
  }
}
