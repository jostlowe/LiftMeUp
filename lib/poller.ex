defmodule Poller do
  use GenServer
  require Logger

  defstruct [:socket, :button_states, :timer_ref]


  ### Public API

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end


  ### Initialization

  def init([]) do
    state = %Poller{}
    |> start_polling_timer
    |> initialize_button_state

    {:ok, state}
  end


  ### Internal Helpers

  defp start_polling_timer(state, interval \\ 100) do
    {:ok, timer_ref} = :timer.send_interval(interval, :do_poll)
    %Poller{state | timer_ref: timer_ref}
  end

  defp initialize_button_state(state) do
    button_states = Order.all_orders
    |> Enum.map(fn order -> {order, 0} end)
    |> Map.new()

    %Poller{state | button_states: button_states}
  end

  defp get_order_button_state(order = %Order{floor: floor, type: type}) do
    {order, Driver.get_order_button_state(floor, type)}
  end

  defp get_button_states() do
    Order.all_orders
    |> Enum.map(&get_order_button_state/1)
    |> Map.new()
  end

  defp get_changed_buttons(old_states, new_states) do

    edge_detector = fn (_button, old_state, new_state) ->
      case {old_state, new_state} do
        {0, 1} -> :rising
        {1, 0} -> :falling
        {val, val} -> :unchanged
      end
    end

    old_states
    |> Map.merge(new_states, edge_detector)
    |> Map.to_list
    |> Enum.filter(fn {_button, changed?} -> changed? == :rising end)
    |> Enum.map(fn {button, _changed?} -> button end)
  end

  ### Callbacks

  def handle_info(:do_poll, %Poller{button_states: old_button_states} = state) do
    new_button_states = get_button_states()
    changed_buttons = get_changed_buttons(old_button_states, new_button_states)

    Enum.each(changed_buttons, fn order ->
      Logger.info("Button Pressed: #{order.type} #{order.floor}")
      LiftMeUp.broker_order(order)
    end)

    {:noreply, %{state | button_states: new_button_states}}

  end

end
