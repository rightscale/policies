define find_unattached_volumes() do

    #get all volumes
    @@all_volumes = rs_cm.volumes.index()

      #search the collection for only volumes with status = available
      @@volumes_not_in_use = select(@@all_volumes, { "status": "available" })

      #For each volume check to see if it was recently created ( we don't want to include a recently created volume to the list of unattached volumes)


      $$size=size(@@volumes_not_in_use)




end
