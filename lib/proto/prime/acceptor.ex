defmodule Proto.Prime.Acceptor do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start(__MODULE__, args)
  end

  def init(state) do
    {:ok, state, {:continue, :is_prime}}
  end

  def handle_continue(:is_prime, state) do
    case :gen_tcp.recv(state[:socket], 0) do
      {:ok, request} ->
        case decode_and_validate(request) do
          {:ok, decoded} ->
            number = decoded["number"]

            is_prime? =
              if is_float(number) do
                false
              else
                Prime.test(number)
              end

            response = Jason.encode!(%{"method" => "isPrime", "prime" => is_prime?})

            :gen_tcp.send(state[:socket], response <> "\n")

            {:noreply, state, {:continue, :is_prime}}

          {:error, _e} ->
            :gen_tcp.send(state[:socket], "{x}\n")
            :gen_tcp.close(state[:socket])
            {:stop, :normal, state}
        end

      {:error, :closed} ->
        Logger.debug("#{inspect(state[:socket])} closed, exiting")
        :gen_tcp.close(state[:socket])
        {:stop, :normal, state}
    end
  end

  def decode_and_validate(request) do
    with {:ok, request} <- Jason.decode(request),
         {:has_method, true} <- {:has_method, Map.has_key?(request, "method")},
         {:method_is_prime, true} <-
           {:method_is_prime, Map.fetch!(request, "method") == "isPrime"},
         {:number, true} <- {:number, Map.has_key?(request, "number")},
         {:is_number, true} <- {:is_number, is_number(Map.fetch!(request, "number"))} do
      {:ok, request}
    else
      {e, _} ->
        {:error, e}
    end
  end
end
