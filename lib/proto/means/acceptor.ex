defmodule Proto.Means.Acceptor do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start(__MODULE__, args)
  end

  def init(state) do
    state = Map.put(state, :prices, %{})
    {:ok, state, {:continue, :means}}
  end

  def handle_continue(:means, state) do
    case :gen_tcp.recv(state[:socket], 9) do
      {:ok, <<"I", timestamp::signed-big-integer-32, price::signed-big-integer-32>>} ->
        if Map.has_key?(state[:prices], price) do
          :gen_tcp.close(state[:socket])
          {:stop, :normal, state}
        else
          state =
            Map.update!(state, :prices, fn prices ->
              Map.put(prices, timestamp, price)
            end)

          {:noreply, state, {:continue, :means}}
        end

      {:ok, <<"Q", mintime::signed-big-integer-32, maxtime::big-integer-32>>} ->
        prices = Map.fetch!(state, :prices)

        prices_in_window =
          prices
          |> Enum.filter(fn {timestamp, _price} ->
            mintime <= timestamp && timestamp <= maxtime
          end)
          |> Enum.map(fn {_timestamp, price} -> price end)

        window_len = Enum.count(prices_in_window)

        if window_len > 0 do
          sum = Enum.sum(prices_in_window)

          mean = (sum / window_len) |> Kernel.ceil()

          :ok = :gen_tcp.send(state[:socket], <<mean::signed-integer-big-32>>)

          {:noreply, state, {:continue, :means}}
        else
          :ok = :gen_tcp.send(state[:socket], <<0::signed-integer-big-32>>)
          {:noreply, state, {:continue, :means}}
        end

      {:ok, <<_::binary-8, _timestamp::big-integer-32, _price::big-integer-32>>} ->
        :gen_tcp.close(state[:socket])
        {:stop, :normal, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, state}
    end
  end
end
