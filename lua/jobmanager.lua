Hooks:PostHook(JobManager,"activate_job","geoguessr_on_activate_job",function(self,job_id,current_stage)
	GeoGuessr:OnMapChanged(self:current_level_id())
end)