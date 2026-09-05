namespace :delivery_intents do
  desc "Re-enqueue pending delivery intents and recover stale claims"
  task reconcile: :environment do
    stale_before = ENV.fetch("STALE_BEFORE", "15").to_i.minutes.ago
    recovered = DeliveryIntent.stale_processing(before: stale_before).update_all(
      status: "pending", claimed_at: nil, available_at: Time.current, updated_at: Time.current
    )
    enqueued = 0
    DeliveryIntent.ready.find_each do |intent|
      enqueued += 1 if intent.enqueue
    end
    puts "Recovered stale intents: #{recovered}"
    puts "Enqueued pending intents: #{enqueued}"
  end
end
