defmodule Proto.Smoke.Acceptor do
  use GenServer

  def start_link(args) do
    GenServer.start(__MODULE__, args)
  end

  def init(state) do
    {:ok, state, {:continue, :echo}}
  end

  def handle_continue(:echo, state) do
    case :gen_tcp.recv(state[:socket], 0) do
      {:ok, packet} ->
        :gen_tcp.send(state[:socket], packet)
        {:noreply, state, {:continue, :echo}}

      {:error, :closed} ->
        :gen_tcp.close(state[:socket])
        {:stop, :normal, state}
    end
  end
end
