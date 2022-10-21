defmodule Proto.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: :proto_pubsub},
      {Proto.ChatTableManager, []},
      ###### connection supervisors
      Supervisor.child_spec({Proto.GenSupervisor, %{sup_name: Proto.Smoke.Supervisor}},
        id: :smoke_sup
      ),
      Supervisor.child_spec({Proto.GenSupervisor, %{sup_name: Proto.Prime.Supervisor}},
        id: :prime_sup
      ),
      Supervisor.child_spec({Proto.GenSupervisor, %{sup_name: Proto.Means.Supervisor}},
        id: :means_sup
      ),
      Supervisor.child_spec({Proto.GenSupervisor, %{sup_name: Proto.BudgetChat.Supervisor}},
        id: :budget_chat_sup
      ),
      Supervisor.child_spec({Proto.GenSupervisor, %{sup_name: Proto.Mob.Supervisor}},
        id: :mob_sup
      ),
      ###### listeners
      Supervisor.child_spec(
        {Proto.GenListener,
         %{
           acceptor: Proto.Smoke.Acceptor,
           supervisor: Proto.Smoke.Supervisor,
           port: 8080,
           options: [
             :binary,
             {:active, false},
             {:packet, 0},
             {:recbuf, :math.pow(2, 16) |> Kernel.floor()}
           ]
         }},
        id: :smoke_listener
      ),
      Supervisor.child_spec(
        {Proto.GenListener,
         %{
           acceptor: Proto.Prime.Acceptor,
           supervisor: Proto.Prime.Supervisor,
           port: 8081,
           options: [
             :binary,
             {:active, false},
             {:packet, :line},
             {:recbuf, :math.pow(2, 16) |> Kernel.floor()}
           ]
         }},
        id: :prime_listener
      ),
      Supervisor.child_spec(
        {Proto.GenListener,
         %{
           acceptor: Proto.Means.Acceptor,
           supervisor: Proto.Means.Supervisor,
           port: 8082,
           options: [
             :binary,
             {:active, false},
             {:packet, :raw},
             {:recbuf, :math.pow(2, 16) |> Kernel.floor()}
           ]
         }},
        id: :means_listener
      ),
      Supervisor.child_spec(
        {Proto.GenListener,
         %{
           acceptor: Proto.BudgetChat.Acceptor,
           supervisor: Proto.BudgetChat.Supervisor,
           port: 8083,
           options: [
             :binary,
             {:active, false},
             {:packet, :line},
             {:recbuf, :math.pow(2, 16) |> Kernel.floor()}
           ]
         }},
        id: :budget_chat_listener
      ),
      {Proto.Unusual.Acceptor, %{port: 8084}},
      Supervisor.child_spec(
        {Proto.GenListener,
         %{
           acceptor: Proto.Mob.Acceptor,
           supervisor: Proto.Mob.Supervisor,
           port: 8085,
           options: [
             :binary,
             {:active, false},
             {:packet, :line},
             {:recbuf, :math.pow(2, 16) |> Kernel.floor()}
           ]
         }},
        id: :mob_listener
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Proto.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
