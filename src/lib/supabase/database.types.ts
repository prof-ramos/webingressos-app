export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.15"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      audit_logs: {
        Row: {
          action: string
          actor_user_id: string | null
          entity_public_id: string
          entity_type: string
          event_id: string | null
          id: number
          metadata: Json
          occurred_at: string
          organization_id: string
          reason: string | null
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          entity_public_id: string
          entity_type: string
          event_id?: string | null
          id?: never
          metadata?: Json
          occurred_at?: string
          organization_id: string
          reason?: string | null
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          entity_public_id?: string
          entity_type?: string
          event_id?: string | null
          id?: never
          metadata?: Json
          occurred_at?: string
          organization_id?: string
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_event_id_fkey"
            columns: ["event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "audit_logs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      check_ins: {
        Row: {
          checked_by: string
          checked_in_at: string
          created_at: string
          device_label: string | null
          event_id: string
          id: string
          organization_id: string
          ticket_id: string
        }
        Insert: {
          checked_by: string
          checked_in_at?: string
          created_at?: string
          device_label?: string | null
          event_id: string
          id?: string
          organization_id: string
          ticket_id: string
        }
        Update: {
          checked_by?: string
          checked_in_at?: string
          created_at?: string
          device_label?: string | null
          event_id?: string
          id?: string
          organization_id?: string
          ticket_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "check_ins_event_id_fkey"
            columns: ["event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "check_ins_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "check_ins_ticket_id_fkey"
            columns: ["ticket_id", "organization_id"]
            isOneToOne: true
            referencedRelation: "tickets"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      event_organizations: {
        Row: {
          created_at: string
          event_id: string
          id: string
          organization_id: string
          role: Database["public"]["Enums"]["event_organization_role"]
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          organization_id: string
          role?: Database["public"]["Enums"]["event_organization_role"]
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          organization_id?: string
          role?: Database["public"]["Enums"]["event_organization_role"]
        }
        Relationships: [
          {
            foreignKeyName: "event_organizations_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_organizations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      event_status_history: {
        Row: {
          actor_user_id: string
          event_id: string
          from_status: Database["public"]["Enums"]["event_status"] | null
          id: string
          occurred_at: string
          organization_id: string
          reason: string | null
          to_status: Database["public"]["Enums"]["event_status"]
        }
        Insert: {
          actor_user_id: string
          event_id: string
          from_status?: Database["public"]["Enums"]["event_status"] | null
          id?: string
          occurred_at?: string
          organization_id: string
          reason?: string | null
          to_status: Database["public"]["Enums"]["event_status"]
        }
        Update: {
          actor_user_id?: string
          event_id?: string
          from_status?: Database["public"]["Enums"]["event_status"] | null
          id?: string
          occurred_at?: string
          organization_id?: string
          reason?: string | null
          to_status?: Database["public"]["Enums"]["event_status"]
        }
        Relationships: [
          {
            foreignKeyName: "event_status_history_event_id_fkey"
            columns: ["event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "event_status_history_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          created_at: string
          created_by: string
          ends_at: string | null
          id: string
          name: string
          organization_id: string
          starts_at: string | null
          status: Database["public"]["Enums"]["event_status"]
        }
        Insert: {
          created_at?: string
          created_by: string
          ends_at?: string | null
          id?: string
          name: string
          organization_id: string
          starts_at?: string | null
          status?: Database["public"]["Enums"]["event_status"]
        }
        Update: {
          created_at?: string
          created_by?: string
          ends_at?: string | null
          id?: string
          name?: string
          organization_id?: string
          starts_at?: string | null
          status?: Database["public"]["Enums"]["event_status"]
        }
        Relationships: [
          {
            foreignKeyName: "events_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      ledger_entries: {
        Row: {
          amount_cents: number
          approved_by: string | null
          created_at: string
          created_by: string
          currency: string
          description: string
          event_id: string
          id: string
          kind: Database["public"]["Enums"]["ledger_entry_kind"]
          occurred_at: string
          organization_id: string
          paid_at: string | null
          status: Database["public"]["Enums"]["ledger_entry_status"]
        }
        Insert: {
          amount_cents: number
          approved_by?: string | null
          created_at?: string
          created_by: string
          currency?: string
          description: string
          event_id: string
          id?: string
          kind: Database["public"]["Enums"]["ledger_entry_kind"]
          occurred_at?: string
          organization_id: string
          paid_at?: string | null
          status?: Database["public"]["Enums"]["ledger_entry_status"]
        }
        Update: {
          amount_cents?: number
          approved_by?: string | null
          created_at?: string
          created_by?: string
          currency?: string
          description?: string
          event_id?: string
          id?: string
          kind?: Database["public"]["Enums"]["ledger_entry_kind"]
          occurred_at?: string
          organization_id?: string
          paid_at?: string | null
          status?: Database["public"]["Enums"]["ledger_entry_status"]
        }
        Relationships: [
          {
            foreignKeyName: "ledger_entries_event_id_fkey"
            columns: ["event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "ledger_entries_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      lots: {
        Row: {
          capacity: number | null
          created_at: string
          currency: string
          event_id: string
          id: string
          name: string
          organization_id: string
          price_cents: number
          sales_end_at: string | null
          sales_start_at: string | null
        }
        Insert: {
          capacity?: number | null
          created_at?: string
          currency?: string
          event_id: string
          id?: string
          name: string
          organization_id: string
          price_cents: number
          sales_end_at?: string | null
          sales_start_at?: string | null
        }
        Update: {
          capacity?: number | null
          created_at?: string
          currency?: string
          event_id?: string
          id?: string
          name?: string
          organization_id?: string
          price_cents?: number
          sales_end_at?: string | null
          sales_start_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "lots_event_id_fkey"
            columns: ["event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "lots_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      order_items: {
        Row: {
          created_at: string
          id: string
          lot_id: string
          order_id: string
          organization_id: string
          quantity: number
          subtotal_cents: number
          unit_price_cents: number
        }
        Insert: {
          created_at?: string
          id?: string
          lot_id: string
          order_id: string
          organization_id: string
          quantity: number
          subtotal_cents: number
          unit_price_cents: number
        }
        Update: {
          created_at?: string
          id?: string
          lot_id?: string
          order_id?: string
          organization_id?: string
          quantity?: number
          subtotal_cents?: number
          unit_price_cents?: number
        }
        Relationships: [
          {
            foreignKeyName: "order_items_lot_id_fkey"
            columns: ["lot_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "order_items_order_id_fkey"
            columns: ["order_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "order_items_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          buyer_email: string | null
          buyer_name: string | null
          buyer_phone: string | null
          created_at: string
          created_by: string
          currency: string
          event_id: string
          id: string
          organization_id: string
          promoter_id: string | null
          status: Database["public"]["Enums"]["order_status"]
          total_cents: number
        }
        Insert: {
          buyer_email?: string | null
          buyer_name?: string | null
          buyer_phone?: string | null
          created_at?: string
          created_by: string
          currency?: string
          event_id: string
          id?: string
          organization_id: string
          promoter_id?: string | null
          status?: Database["public"]["Enums"]["order_status"]
          total_cents: number
        }
        Update: {
          buyer_email?: string | null
          buyer_name?: string | null
          buyer_phone?: string | null
          created_at?: string
          created_by?: string
          currency?: string
          event_id?: string
          id?: string
          organization_id?: string
          promoter_id?: string | null
          status?: Database["public"]["Enums"]["order_status"]
          total_cents?: number
        }
        Relationships: [
          {
            foreignKeyName: "orders_event_id_fkey"
            columns: ["event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "orders_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_promoter_id_fkey"
            columns: ["promoter_id", "event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "promoters"
            referencedColumns: ["id", "event_id", "organization_id"]
          },
        ]
      }
      organization_memberships: {
        Row: {
          created_at: string
          id: string
          organization_id: string
          role: Database["public"]["Enums"]["organization_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          organization_id: string
          role: Database["public"]["Enums"]["organization_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          organization_id?: string
          role?: Database["public"]["Enums"]["organization_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_memberships_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
      promoters: {
        Row: {
          active: boolean
          commission_rate_basis_points: number
          contact: string | null
          created_at: string
          display_name: string
          event_id: string
          id: string
          organization_id: string
        }
        Insert: {
          active?: boolean
          commission_rate_basis_points?: number
          contact?: string | null
          created_at?: string
          display_name: string
          event_id: string
          id?: string
          organization_id: string
        }
        Update: {
          active?: boolean
          commission_rate_basis_points?: number
          contact?: string | null
          created_at?: string
          display_name?: string
          event_id?: string
          id?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promoters_event_id_fkey"
            columns: ["event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "promoters_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      tickets: {
        Row: {
          created_at: string
          event_id: string
          id: string
          order_item_id: string
          organization_id: string
          public_code: string
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          order_item_id: string
          organization_id: string
          public_code?: string
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          order_item_id?: string
          organization_id?: string
          public_code?: string
        }
        Relationships: [
          {
            foreignKeyName: "tickets_event_id_fkey"
            columns: ["event_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "tickets_order_item_id_fkey"
            columns: ["order_item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "tickets_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      can_access_event: { Args: { target_event_id: string }; Returns: boolean }
      check_in_ticket: {
        Args: {
          scanner_device_label?: string
          target_event_public_id: string
          ticket_code: string
        }
        Returns: {
          checked_in_at: string
          reason: string
          status: string
          ticket_public_id: string
        }[]
      }
      create_organization: {
        Args: { organization_name: string }
        Returns: {
          created_at: string
          id: string
          name: string
        }
        SetofOptions: {
          from: "*"
          to: "organizations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      has_event_role: {
        Args: {
          allowed_roles: Database["public"]["Enums"]["organization_role"][]
          target_event_id: string
        }
        Returns: boolean
      }
      has_org_role: {
        Args: {
          allowed_roles: Database["public"]["Enums"]["organization_role"][]
          target_organization_id: string
        }
        Returns: boolean
      }
      is_org_member: {
        Args: { target_organization_id: string }
        Returns: boolean
      }
      record_audit_log: {
        Args: {
          target_action: string
          target_entity_public_id: string
          target_entity_type: string
          target_event_id: string
          target_metadata?: Json
          target_organization_id: string
          target_reason?: string
        }
        Returns: {
          action: string
          actor_user_id: string | null
          entity_public_id: string
          entity_type: string
          event_id: string | null
          id: number
          metadata: Json
          occurred_at: string
          organization_id: string
          reason: string | null
        }
        SetofOptions: {
          from: "*"
          to: "audit_logs"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      uuidv7: { Args: never; Returns: string }
    }
    Enums: {
      event_organization_role: "owner" | "collaborator"
      event_status:
        | "rascunho"
        | "planejado"
        | "vendas_abertas"
        | "encerrado"
        | "prestacao_contas_fechada"
        | "cancelado"
      ledger_entry_kind:
        | "revenue"
        | "expense"
        | "commission"
        | "split"
        | "payout"
      ledger_entry_status: "previsto" | "aprovado" | "pago"
      order_status: "pending" | "confirmed" | "cancelled" | "refunded"
      organization_role: "owner" | "finance" | "ops" | "gate"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      event_organization_role: ["owner", "collaborator"],
      event_status: [
        "rascunho",
        "planejado",
        "vendas_abertas",
        "encerrado",
        "prestacao_contas_fechada",
        "cancelado",
      ],
      ledger_entry_kind: [
        "revenue",
        "expense",
        "commission",
        "split",
        "payout",
      ],
      ledger_entry_status: ["previsto", "aprovado", "pago"],
      order_status: ["pending", "confirmed", "cancelled", "refunded"],
      organization_role: ["owner", "finance", "ops", "gate"],
    },
  },
} as const
