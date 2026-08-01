defmodule ExMUSH.DB do
  @spec dbtime_to_wtime(%DateTime{}) :: {non_neg_integer(), %DateTime{}}
  def dbtime_to_wtime(%DateTime{} = datetime) do
    unix = datetime |> DateTime.to_unix()
    {unix, datetime}
  end

  @spec wtime_to_dbtime({non_neg_integer(), %DateTime{}}) :: %DateTime{}
  def wtime_to_dbtime({_unix, %DateTime{} = datetime}), do: datetime
end
