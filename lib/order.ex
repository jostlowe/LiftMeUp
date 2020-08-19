defmodule Order do

  @order_types [:hall_up, :hall_down, :cab]
  @max_floor 3

  defguard is_order_type(value) when value in @order_types
  defguard is_floor(value) when value in 0..@max_floor

  defstruct [:floor, :type, :owner]

  def get_order_floors(order_type) when is_order_type(order_type) do
    case order_type do
      :hall_down -> 1..@max_floor
      :hall_up -> 0..@max_floor-1
      :cab -> 0..@max_floor
    end
  end

  def all_orders(order_type) when is_order_type(order_type) do
   order_type
    |> get_order_floors()
    |> Enum.map(fn flr -> %Order{floor: flr, type: order_type} end)
  end

  def all_orders do
    @order_types
    |> Enum.flat_map(&all_orders/1)
  end

end
