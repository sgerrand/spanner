defmodule Spanner do
  @bundle_extension ".cog"
  @skinny_bundle_extension ".json"

  def bundle_extension(),
    do: @bundle_extension

  def skinny_bundle_extension(),
    do: @skinny_bundle_extension
end
