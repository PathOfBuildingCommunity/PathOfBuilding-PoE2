import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useRef } from "react";
import { api } from "./client";
import type { Advice, Budget, ClassInfo, ConfigOption, Overview, ReferenceCompare, ReferenceSummary, SkillGroup, SlotItem, TreeLayout } from "./types";

/** Poll the server revision; when an agent (MCP) or another tab changes the build, refetch everything. */
export function useLiveRevision() {
  const qc = useQueryClient();
  const last = useRef<number | null>(null);
  const { data } = useQuery({
    queryKey: ["revision"],
    queryFn: () => api.get<{ revision: number }>("/revision"),
    refetchInterval: 1500,
  });
  useEffect(() => {
    if (!data) return;
    if (last.current !== null && last.current !== data.revision) {
      qc.invalidateQueries({ predicate: (q) => q.queryKey[0] !== "revision" && q.queryKey[0] !== "static" });
    }
    last.current = data.revision;
  }, [data, qc]);
  return data?.revision;
}

export const useOverview = () => useQuery({ queryKey: ["build"], queryFn: () => api.get<Overview>("/build") });
export const useSkills = () => useQuery({ queryKey: ["skills"], queryFn: () => api.get<SkillGroup[]>("/skills") });
export const useItems = () =>
  useQuery({ queryKey: ["items"], queryFn: () => api.get<SlotItem[]>("/items?includeEmpty=true") });
export const useSlots = () =>
  useQuery({ queryKey: ["static", "slots"], queryFn: () => api.get<string[]>("/items/slots"), staleTime: Infinity });
export const useClasses = () =>
  useQuery({ queryKey: ["static", "classes"], queryFn: () => api.get<ClassInfo[]>("/classes"), staleTime: Infinity });
export const useTreeLayout = () => useQuery({ queryKey: ["tree-layout"], queryFn: () => api.get<TreeLayout>("/tree/layout") });
export const useConfig = (all: boolean) =>
  useQuery({ queryKey: ["config", all], queryFn: () => api.get<ConfigOption[]>(`/config${all ? "?all=true" : ""}`) });

/** A mutation that refreshes all build data afterwards. */
export function useBuildMutation<TVars, TRes = unknown>(fn: (vars: TVars) => Promise<TRes>) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: fn,
    onSuccess: () => qc.invalidateQueries({ predicate: (q) => q.queryKey[0] !== "static" }),
  });
}

/** The loaded reference guide (.build), or null. */
export const useReference = () =>
  useQuery({ queryKey: ["reference"], queryFn: () => api.get<ReferenceSummary | null>("/reference") });
export const useReferenceCompare = (enabled: boolean, level: number | null = null) =>
  useQuery({
    queryKey: ["reference-compare", level],
    queryFn: () => api.get<ReferenceCompare>(`/reference/compare${level ? `?level=${level}` : ""}`),
    enabled,
  });

/** Next point / point to move / attribute advice for the live build (follows the reference guide if loaded). */
export const useAdvice = (metric: Advice["metric"], enabled = true) =>
  useQuery({ queryKey: ["advice", metric], queryFn: () => api.get<Advice>(`/advisor?metric=${metric}`), enabled });

/** Spirit/totem budget and main-skill DPS across all totems. */
export const useBudget = () => useQuery({ queryKey: ["budget"], queryFn: () => api.get<Budget>("/budget") });
